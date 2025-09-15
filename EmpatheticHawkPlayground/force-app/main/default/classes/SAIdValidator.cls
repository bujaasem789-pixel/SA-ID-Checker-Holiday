/**
 * @description SA ID Number validation and decoding utility class
 * @author CloudSmiths Technical Assignment
 */
public class SAIdValidator {
    
    /**
     * @description Wrapper class to hold decoded ID information
     */
    public class IdDetails {
        @AuraEnabled public Date dateOfBirth { get; set; }
        @AuraEnabled public String gender { get; set; }
        @AuraEnabled public Boolean isSACitizen { get; set; }
        @AuraEnabled public Integer birthYear { get; set; }
        @AuraEnabled public String formattedDateOfBirth { get; set; }
        
        public IdDetails() {
            this.dateOfBirth = null;
            this.gender = '';
            this.isSACitizen = false;
            this.birthYear = null;
            this.formattedDateOfBirth = '';
        }
    }
    
    /**
     * @description Validates SA ID number using Luhn algorithm and format checks
     * @param idNumber The 13-digit SA ID number as string
     * @return Boolean indicating if ID is valid
     */
    public static Boolean isValidSAId(String idNumber) {
        try {
            // Basic format validation
            if (String.isBlank(idNumber) || idNumber.length() != 13 || !idNumber.isNumeric()) {
                return false;
            }
            
            // Extract date components
            String dateStr = idNumber.substring(0, 6);
            Integer yearVal = Integer.valueOf(dateStr.substring(0, 2));
            Integer monthVal = Integer.valueOf(dateStr.substring(2, 4));
            Integer dayVal = Integer.valueOf(dateStr.substring(4, 6));
            
            // Validate date components
            if (!isValidDate(yearVal, monthVal, dayVal)) {
                return false;
            }
            
            // Validate gender digit (positions 6-9)
            String genderDigits = idNumber.substring(6, 10);
            if (!genderDigits.isNumeric()) {
                return false;
            }
            
            // Validate citizenship digit (position 10)
            String citizenshipDigit = idNumber.substring(10, 11);
            if (citizenshipDigit != '0' && citizenshipDigit != '1') {
                return false;
            }
            
            // Validate race digit (position 11) - should always be 8 for modern IDs
            String raceDigit = idNumber.substring(11, 12);
            if (raceDigit != '8') {
                return false;
            }
            
            // Validate checksum using Luhn algorithm
            return validateChecksum(idNumber);
            
        } catch (Exception e) {
            System.debug('Error validating SA ID: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Extracts and decodes information from a valid SA ID number
     * @param idNumber The 13-digit SA ID number as string
     * @return IdDetails object with decoded information
     */
    public static IdDetails extractDetails(String idNumber) {
        IdDetails details = new IdDetails();
        
        try {
            if (!isValidSAId(idNumber)) {
                return details;
            }
            
            // Extract date of birth
            String dateStr = idNumber.substring(0, 6);
            Integer yearVal = Integer.valueOf(dateStr.substring(0, 2));
            Integer monthVal = Integer.valueOf(dateStr.substring(2, 4));
            Integer dayVal = Integer.valueOf(dateStr.substring(4, 6));
            
            // Determine full year (assuming current cutoff is reasonable)
            Integer currentYear = Date.today().year();
            Integer currentCentury = currentYear / 100;
            Integer fullYear;
            
            if (yearVal <= (currentYear - (currentCentury * 100))) {
                fullYear = (currentCentury * 100) + yearVal;
            } else {
                fullYear = ((currentCentury - 1) * 100) + yearVal;
            }
            
            details.birthYear = fullYear;
            details.dateOfBirth = Date.newInstance(fullYear, monthVal, dayVal);
            details.formattedDateOfBirth = details.dateOfBirth.format();
            
            // Extract gender
            Integer genderDigit = Integer.valueOf(idNumber.substring(6, 10));
            details.gender = (genderDigit < 5000) ? 'Female' : 'Male';
            
            // Extract citizenship
            String citizenshipDigit = idNumber.substring(10, 11);
            details.isSACitizen = (citizenshipDigit == '0');
            
        } catch (Exception e) {
            System.debug('Error extracting SA ID details: ' + e.getMessage());
        }
        
        return details;
    }
    
    /**
     * @description Validates date components for logical correctness
     * @param yearVal Two-digit year
     * @param monthVal Month (1-12)
     * @param dayVal Day (1-31)
     * @return Boolean indicating if date is valid
     */
    private static Boolean isValidDate(Integer yearVal, Integer monthVal, Integer dayVal) {
        // Basic range checks
        if (monthVal < 1 || monthVal > 12 || dayVal < 1 || dayVal > 31) {
            return false;
        }
        
        // Days in month validation
        List<Integer> daysInMonth = new List<Integer>{31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
        
        // Handle leap year for February
        if (monthVal == 2) {
            Integer fullYear = (yearVal <= 24) ? 2000 + yearVal : 1900 + yearVal; // Assuming reasonable cutoff
            Boolean isLeapYear = (Math.mod(fullYear, 4) == 0 && Math.mod(fullYear, 100) != 0) || 
                                 (Math.mod(fullYear, 400) == 0);
            if (isLeapYear && dayVal <= 29) {
                return true;
            } else if (!isLeapYear && dayVal <= 28) {
                return true;
            } else {
                return false;
            }
        }
        
        return dayVal <= daysInMonth[monthVal - 1];
    }
    
    /**
     * @description Validates checksum digit using Luhn algorithm
     * @param idNumber The 13-digit SA ID number
     * @return Boolean indicating if checksum is valid
     */
    private static Boolean validateChecksum(String idNumber) {
        try {
            String first12Digits = idNumber.substring(0, 12);
            Integer providedChecksum = Integer.valueOf(idNumber.substring(12, 13));
            
            Integer totalSum = 0;
            
            // Process digits according to Luhn algorithm
            for (Integer i = 0; i < 12; i++) {
                Integer digit = Integer.valueOf(first12Digits.substring(i, i + 1));
                
                if (Math.mod(i, 2) == 0) {
                    // Odd positions (1st, 3rd, 5th, etc.) - add as is
                    totalSum += digit;
                } else {
                    // Even positions (2nd, 4th, 6th, etc.) - double and handle carry
                    Integer doubled = digit * 2;
                    if (doubled > 9) {
                        doubled = Math.mod(doubled, 10) + 1; // Add the digits of the doubled number
                    }
                    totalSum += doubled;
                }
            }
            
            // Calculate expected checksum
            Integer calculatedChecksum = (10 - Math.mod(totalSum, 10));
            if (calculatedChecksum == 10) {
                calculatedChecksum = 0;
            }
            
            return calculatedChecksum == providedChecksum;
            
        } catch (Exception e) {
            System.debug('Error in checksum validation: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Formats SA ID number with spaces for display
     * @param idNumber Raw SA ID number
     * @return Formatted ID number (YYMMDD GGGG C R C)
     */
    public static String formatIdNumber(String idNumber) {
        if (String.isBlank(idNumber) || idNumber.length() != 13) {
            return idNumber;
        }
        
        return idNumber.substring(0, 6) + ' ' + 
               idNumber.substring(6, 10) + ' ' + 
               idNumber.substring(10, 11) + ' ' + 
               idNumber.substring(11, 12) + ' ' + 
               idNumber.substring(12, 13);
    }
}