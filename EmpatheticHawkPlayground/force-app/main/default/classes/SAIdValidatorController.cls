/**
 * @description Streamlined controller class for SA ID validation and holiday lookup
 * @author CloudSmiths Technical Assignment
 */
public with sharing class SAIdValidatorController {
    
    /**
     * @description Wrapper class for search results
     */
    public class SearchResult {
        @AuraEnabled public Boolean isValid { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public SAIdValidator.IdDetails idDetails { get; set; }
        @AuraEnabled public CalendarificService.HolidayApiResponse holidayResponse { get; set; }
        @AuraEnabled public Integer searchCount { get; set; }
        @AuraEnabled public String formattedIdNumber { get; set; }
        
        public SearchResult() {
            this.isValid = false;
            this.errorMessage = '';
            this.idDetails = new SAIdValidator.IdDetails();
            this.holidayResponse = new CalendarificService.HolidayApiResponse();
            this.searchCount = 0;
            this.formattedIdNumber = '';
        }
    }
    
    /**
     * @description Main method to validate SA ID and retrieve holiday information
     * @param idNumber The SA ID number to validate and process
     * @return SearchResult with validation results and holiday data
     */
    @AuraEnabled(cacheable=false)
    public static SearchResult validateAndSearch(String idNumber) {
        SearchResult result = new SearchResult();
        
        try {
            // Clean the input
            String cleanIdNumber = cleanIdNumber(idNumber);
            
            // Validate the ID number
            if (!SAIdValidator.isValidSAId(cleanIdNumber)) {
                result.errorMessage = 'Invalid SA ID Number. Please check the format and try again.';
                return result;
            }
            
            // Extract ID details
            SAIdValidator.IdDetails details = SAIdValidator.extractDetails(cleanIdNumber);
            result.idDetails = details;
            result.formattedIdNumber = SAIdValidator.formatIdNumber(cleanIdNumber);
            result.isValid = true;
            
            // Save/update the database record first
            SA_ID_Search__c searchRecord = SAIdDatabaseService.upsertSAIdRecord(cleanIdNumber, details);
            result.searchCount = Integer.valueOf(searchRecord.Search_Count__c);
            
            // Get holidays for the birth year
            try {
                System.debug('Attempting to get holidays for year: ' + details.birthYear);
                CalendarificService.HolidayApiResponse holidayResponse = 
                    CalendarificService.getHolidaysForYear(details.birthYear);
                
                result.holidayResponse = holidayResponse;
                
                if (holidayResponse.success) {
                    System.debug('Successfully retrieved ' + holidayResponse.holidays.size() + ' holidays');
                } else {
                    System.debug('Holiday API failed: ' + holidayResponse.errorMessage);
                    // Don't fail the entire operation, just set a user-friendly message
                    result.holidayResponse.errorMessage = 'Unable to retrieve holiday information. You can retry to load holidays.';
                }
                
            } catch (Exception holidayException) {
                System.debug('Holiday API exception: ' + holidayException.getMessage());
                // Create a failed response but don't break the main flow
                result.holidayResponse = new CalendarificService.HolidayApiResponse();
                result.holidayResponse.success = false;
                result.holidayResponse.errorMessage = 'Holiday service temporarily unavailable. You can retry to load holidays.';
                result.holidayResponse.holidayYear = details.birthYear;
            }
            
        } catch (Exception e) {
            result.errorMessage = 'An error occurred while processing your request: ' + e.getMessage();
            System.debug('Error in validateAndSearch: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return result;
    }
    
    /**
     * @description Validates SA ID number format only (for real-time validation)
     * @param idNumber The SA ID number to validate
     * @return Boolean indicating if the format is valid
     */
    @AuraEnabled(cacheable=true)
    public static Boolean validateIdFormat(String idNumber) {
        try {
            String cleanIdNumber = cleanIdNumber(idNumber);
            return SAIdValidator.isValidSAId(cleanIdNumber);
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * @description Cleans and formats the input ID number
     * @param idNumber Raw input ID number
     * @return Cleaned ID number (digits only)
     */
    private static String cleanIdNumber(String idNumber) {
        if (String.isBlank(idNumber)) {
            return '';
        }
        return idNumber.replaceAll('\\D', '');
    }
    
    /**
     * @description Retrieves holiday information for a specific year
     * @param targetYear The year to get holidays for
     * @return HolidayApiResponse with holiday data
     */
    @AuraEnabled(cacheable=false)
    public static CalendarificService.HolidayApiResponse getHolidaysForYear(Integer targetYear) {
        try {
            return CalendarificService.getHolidaysForYear(targetYear);
        } catch (Exception e) {
            CalendarificService.HolidayApiResponse errorResponse = new CalendarificService.HolidayApiResponse();
            errorResponse.errorMessage = 'Error retrieving holidays: ' + e.getMessage();
            errorResponse.holidayYear = targetYear;
            return errorResponse;
        }
    }
}