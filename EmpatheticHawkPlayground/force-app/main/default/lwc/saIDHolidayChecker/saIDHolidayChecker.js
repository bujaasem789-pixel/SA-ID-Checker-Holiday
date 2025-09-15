import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import validateAndSearch from '@salesforce/apex/SAIdValidatorController.validateAndSearch';
import validateIdFormat from '@salesforce/apex/SAIdValidatorController.validateIdFormat';
import getHolidaysForYear from '@salesforce/apex/SAIdValidatorController.getHolidaysForYear';

export default class SaIdHolidayChecker extends LightningElement {
    @track idNumber = '';
    @track isValidId = false;
    @track isValidating = false;
    @track isSearching = false;
    @track hasResults = false;
    @track hasError = false;
    @track errorMessage = '';
    @track validationMessage = '';
    @track searchResults = {};
    
    // Debouncing
    validationTimeout;
    
    // Results data
    @track idDetails = {};
    @track holidayResponse = {};
    @track searchCount = 0;
    @track formattedIdNumber = '';
    @track holidaysOnBirthDate = [];

    /**
     * Handles input changes with real-time validation
     */
    handleInputChange(event) {
        this.idNumber = event.target.value;
        this.hasError = false;
        this.errorMessage = '';
        this.validationMessage = '';
        
        // Clear existing timeout
        if (this.validationTimeout) {
            clearTimeout(this.validationTimeout);
        }
        
        // Debounce validation for better UX
        if (this.idNumber && this.idNumber.length >= 10) {
            this.isValidating = true;
            this.validationTimeout = setTimeout(() => {
                this.performRealtimeValidation();
            }, 500);
        } else {
            this.isValidId = false;
            this.isValidating = false;
            if (this.idNumber.length > 0 && this.idNumber.length < 13) {
                this.validationMessage = 'ID number must be 13 digits long';
            }
        }
    }

    /**
     * Handles Enter key press for search
     */
    handleKeyDown(event) {
        if (event.key === 'Enter' && this.isValidId && !this.isSearchDisabled) {
            this.handleSearch();
        }
    }

    /**
     * Performs real-time validation without full search
     */
    async performRealtimeValidation() {
        try {
            const isValid = await validateIdFormat({ idNumber: this.idNumber });
            this.isValidId = isValid;
            this.isValidating = false;
            
            if (isValid) {
                this.validationMessage = 'Valid SA ID Number ✓';
            } else {
                this.validationMessage = 'Invalid SA ID Number format';
            }
        } catch (error) {
            console.error('Validation error:', error);
            this.isValidating = false;
            this.isValidId = false;
            this.validationMessage = 'Validation error occurred';
        }
    }

    /**
     * Main search handler
     */
    async handleSearch() {
        if (!this.isValidId || this.isSearching) {
            return;
        }

        this.isSearching = true;
        this.hasError = false;
        this.hasResults = false;
        this.errorMessage = '';

        try {
            const result = await validateAndSearch({ idNumber: this.idNumber });
            
            if (result.isValid) {
                this.processSuccessfulSearch(result);
            } else {
                this.hasError = true;
                this.errorMessage = result.errorMessage || 'Invalid SA ID Number';
            }
        } catch (error) {
            console.error('Search error:', error);
            this.hasError = true;
            this.errorMessage = 'An unexpected error occurred. Please try again.';
            this.showToast('Error', 'Failed to process your request', 'error');
        } finally {
            this.isSearching = false;
        }
    }

    /**
     * Processes successful search results
     */
    processSuccessfulSearch(result) {
        this.idDetails = result.idDetails || {};
        this.holidayResponse = result.holidayResponse || {};
        this.searchCount = result.searchCount || 0;
        this.formattedIdNumber = result.formattedIdNumber || '';
        
        // Check for holidays on birth date
        //this.checkHolidaysOnBirthDate();
        this.handleRetryHolidays();

        
        this.hasResults = true;
        
        // Show success toast
        /*this.showToast(
            'Success!', 
            `Found ${this.holidayCount} holidays for ${this.idDetails.birthYear}`, 
            'success'
        );*/

        // Scroll to results after a brief delay
        setTimeout(() => {
            this.scrollToResults();
        }, 300);
    }

    /**
     * Checks if there are holidays on the person's birth date
     */
    checkHolidaysOnBirthDate() {
        this.holidaysOnBirthDate = [];
        
        if (!this.idDetails.dateOfBirth || !this.holidayResponse.holidays) {
            return;
        }

        const birthDate = new Date(this.idDetails.dateOfBirth);
        const birthMonth = (birthDate.getMonth() + 1).toString().padStart(2, '0');
        const birthDay = birthDate.getDate().toString().padStart(2, '0');
        const birthDateString = `${this.idDetails.birthYear}-${birthMonth}-${birthDay}`;

        this.holidaysOnBirthDate = this.holidayResponse.holidays.filter(holiday => 
            holiday.holidayDate === birthDateString
        );
    }

    /**
     * Retry holiday API call
     */
    async handleRetryHolidays() {
        if (!this.idDetails.birthYear) return;

        try {
            const holidayResponse = await getHolidaysForYear({ targetYear: this.idDetails.birthYear });
            this.holidayResponse = holidayResponse;
            this.checkHolidaysOnBirthDate();
            
            if (holidayResponse.success) {
                this.showToast('Success!', 'Holiday information retrieved', 'success');
            }
        } catch (error) {
            console.error('Retry holidays error:', error);
            this.showToast('Error', 'Failed to retrieve holidays', 'error');
        }
    }

    /**
     * Scrolls to results section smoothly
     */
    scrollToResults() {
        const resultsElement = this.template.querySelector('.results-section');
        if (resultsElement) {
            resultsElement.scrollIntoView({ 
                behavior: 'smooth', 
                block: 'start' 
            });
        }
    }

    /**
     * Shows toast message
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'pester'
        });
        this.dispatchEvent(event);
    }

    /**
     * Computed Properties
     */
    get inputClass() {
        let baseClass = 'input-field';
        if (this.isValidId) {
            baseClass += ' input-valid';
        } else if (this.idNumber.length > 0 && !this.isValidating) {
            baseClass += ' input-invalid';
        }
        return baseClass;
    }

    get validationMessageClass() {
        let baseClass = 'validation-message';
        if (this.isValidId) {
            baseClass += ' validation-success';
        } else {
            baseClass += ' validation-error';
        }
        return baseClass;
    }

    get searchButtonClass() {
        return 'search-button';
    }

    get isSearchDisabled() {
        return !this.isValidId || this.isSearching || this.isValidating;
    }

    get showValidIcon() {
        return this.isValidId && !this.isValidating;
    }

    get showInvalidIcon() {
        return !this.isValidId && this.idNumber.length > 0 && !this.isValidating;
    }

    get formattedDateOfBirth() {
        if (!this.idDetails.dateOfBirth) return '';
        
        try {
            const birthDate = new Date(this.idDetails.dateOfBirth);
            return birthDate.toLocaleDateString('en-ZA', {
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric'
            });
        } catch (error) {
            return this.idDetails.formattedDateOfBirth || '';
        }
    }

    get genderBadgeClass() {
        const gender = this.idDetails.gender;
        if (gender === 'Male') {
            return 'gender-badge gender-male';
        } else if (gender === 'Female') {
            return 'gender-badge gender-female';
        }
        return 'gender-badge';
    }

    get citizenshipBadgeClass() {
        return this.idDetails.isSACitizen 
            ? 'citizenship-badge citizenship-sa' 
            : 'citizenship-badge citizenship-non-sa';
    }

    get citizenshipText() {
        return this.idDetails.isSACitizen ? 'SA Citizen' : 'Non-SA Citizen';
    }

    get holidayCount() {
        return this.holidayResponse.holidays ? this.holidayResponse.holidays.length : 0;
    }

    get hasHolidaysOnBirthDate() {
        return this.holidaysOnBirthDate && this.holidaysOnBirthDate.length > 0;
    }

    /**
     * Lifecycle Hooks
     */
    connectedCallback() {
        console.log('SA ID Holiday Checker component initialized');
    }

    disconnectedCallback() {
        if (this.validationTimeout) {
            clearTimeout(this.validationTimeout);
        }
    }

    renderedCallback() {
        const inputElement = this.template.querySelector('input');
        if (inputElement && !this.hasResults && !this.hasError) {
            setTimeout(() => {
                if (inputElement === this.template.activeElement) return;
                inputElement.focus();
            }, 100);
        }
    }

    /**
     * Error Boundary
     */
    errorCallback(error, stack) {
        console.error('Component error:', error);
        console.error('Stack trace:', stack);
        
        this.hasError = true;
        this.errorMessage = 'A component error occurred. Please refresh the page.';
        this.isSearching = false;
        this.isValidating = false;
        
        this.showToast(
            'Component Error', 
            'An unexpected error occurred. Please refresh the page.', 
            'error'
        );
    }

    /**
     * Utility Methods
     */
    formatDate(dateString) {
        if (!dateString) return '';
        
        try {
            const targetDate = new Date(dateString);
            return targetDate.toLocaleDateString('en-ZA', {
                month: 'short',
                day: 'numeric'
            });
        } catch (error) {
            return dateString;
        }
    }

    resetComponent() {
        this.idNumber = '';
        this.isValidId = false;
        this.isValidating = false;
        this.isSearching = false;
        this.hasResults = false;
        this.hasError = false;
        this.errorMessage = '';
        this.validationMessage = '';
        this.searchResults = {};
        this.idDetails = {};
        this.holidayResponse = {};
        this.searchCount = 0;
        this.formattedIdNumber = '';
        this.holidaysOnBirthDate = [];
        
        if (this.validationTimeout) {
            clearTimeout(this.validationTimeout);
        }
    }

    /**
     * Public API Methods
     */
    @api
    async searchWithId(idNumber) {
        this.idNumber = idNumber;
        await this.performRealtimeValidation();
        
        if (this.isValidId) {
            await this.handleSearch();
        }
    }

    @api
    getCurrentResults() {
        return {
            idDetails: this.idDetails,
            holidayResponse: this.holidayResponse,
            searchCount: this.searchCount,
            isValid: this.isValidId,
            hasResults: this.hasResults
        };
    }

    @api
    reset() {
        this.resetComponent();
    }
}