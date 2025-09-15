/**
 * @description Service class for integrating with Calendarific Holiday API
 * @author CloudSmiths Technical Assignment
 */
public class CalendarificService {
    
    private static final String API_BASE_URL = Label.Calendarific_Base_URL;
    private static final String API_KEY = Label.Calendarific_API_Key;
    private static final String COUNTRY_CODE = Label.Calendarific_Country_Code;
    
    /**
     * @description Wrapper class for holiday information
     */
    public class Holiday {
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String holidayDate { get; set; }
        @AuraEnabled public String holidayType { get; set; }
        @AuraEnabled public Boolean isPrimary { get; set; }
        
        public Holiday() {
            this.name = '';
            this.description = '';
            this.holidayDate = '';
            this.holidayType = '';
            this.isPrimary = false;
        }
    }
    
    /**
     * @description Response wrapper for API results
     */
    public class HolidayApiResponse {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public List<Holiday> holidays { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public Integer holidayYear { get; set; }
        
        public HolidayApiResponse() {
            this.success = false;
            this.holidays = new List<Holiday>();
            this.errorMessage = '';
            this.holidayYear = null;
        }
    }
    
    /**
     * @description Synchronous method to get holidays for a specific year
     * @param holidayYear The year to get holidays for
     * @return HolidayApiResponse with holiday data or error information
     */
    public static HolidayApiResponse getHolidaysForYear(Integer holidayYear) {
        HolidayApiResponse response = new HolidayApiResponse();
        response.holidayYear = holidayYear;
        
        try {
            // Build URL with national type filter (according to API docs)
            String apiUrl = API_BASE_URL + 
                           '?api_key=' + API_KEY + 
                           '&country=' + COUNTRY_CODE + 
                           '&year=' + holidayYear +
                           '&type=national';
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(apiUrl);
            request.setMethod('GET');
            request.setTimeout(30000);
            request.setHeader('Accept', 'application/json');
            request.setHeader('User-Agent', 'Salesforce-SA-ID-Checker/1.0');
            
            System.debug('Making API call to: ' + apiUrl);
            HttpResponse httpResponse = http.send(request);
            
            System.debug('Response Status: ' + httpResponse.getStatusCode());
            System.debug('Response Body: ' + httpResponse.getBody());
            
            if (httpResponse.getStatusCode() == 200) {
                String responseBody = httpResponse.getBody();
                
                // Check if response is empty or null
                if (String.isBlank(responseBody)) {
                    response.errorMessage = 'Empty response from API';
                    return response;
                }
                
                Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                System.debug('Parsed JSON Response: ' + JSON.serialize(jsonResponse));
                
                // Check meta code for success
                if (jsonResponse.containsKey('meta')) {
                    Map<String, Object> meta = (Map<String, Object>) jsonResponse.get('meta');
                    Integer code = (Integer) meta.get('code');
                    if (code != 200) {
                        response.errorMessage = 'API returned error code: ' + code;
                        return response;
                    }
                }
                
                if (jsonResponse.containsKey('response')) {
                    Map<String, Object> responseData = (Map<String, Object>) jsonResponse.get('response');
                    System.debug('Response data: ' + JSON.serialize(responseData));
                    
                    if (responseData.containsKey('holidays')) {
                        List<Object> holidaysData = (List<Object>) responseData.get('holidays');
                        System.debug('Holidays count: ' + holidaysData.size());
                        
                        if (holidaysData.isEmpty()) {
                            response.errorMessage = 'No national holidays found for the specified year and country';
                            return response;
                        }
                        
                        response.holidays = parseHolidays(holidaysData);
                        response.success = true;
                        System.debug('API success: ' + response.holidays.size() + ' national holidays found for ' + holidayYear);
                    } else {
                        response.errorMessage = 'No holidays found in API response';
                        System.debug('Response structure: ' + JSON.serialize(responseData));
                    }
                } else {
                    response.errorMessage = 'Invalid API response structure - missing response key';
                    System.debug('Full response: ' + JSON.serialize(jsonResponse));
                }
            } else if (httpResponse.getStatusCode() == 401) {
                response.errorMessage = 'API authentication failed. Please check the API key.';
            } else if (httpResponse.getStatusCode() == 403) {
                response.errorMessage = 'API access forbidden. API key may be invalid or expired.';
            } else if (httpResponse.getStatusCode() == 422) {
                response.errorMessage = 'Invalid parameters. Please check the year and country code.';
            } else if (httpResponse.getStatusCode() == 429) {
                response.errorMessage = 'API rate limit exceeded. Please try again later.';
            } else if (httpResponse.getStatusCode() == 500) {
                response.errorMessage = 'Calendarific API server error. Please try again later.';
            } else {
                response.errorMessage = 'API request failed with status: ' + httpResponse.getStatusCode() + ' - ' + httpResponse.getStatus();
                System.debug('API error response: ' + httpResponse.getBody());
            }
            
        } catch (Exception e) {
            response.errorMessage = 'API exception: ' + e.getMessage();
            System.debug('API exception: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return response;
    }
    
    /**
     * @description Parses holiday data from Calendarific API response
     */
    private static List<Holiday> parseHolidays(List<Object> holidaysData) {
        List<Holiday> holidays = new List<Holiday>();
        
        for (Object holidayObj : holidaysData) {
            Map<String, Object> holidayMap = (Map<String, Object>) holidayObj;
            
            Holiday holiday = new Holiday();
            holiday.name = (String) holidayMap.get('name');
            holiday.description = (String) holidayMap.get('description');
            
            // Parse date information
            if (holidayMap.containsKey('date')) {
                Map<String, Object> dateMap = (Map<String, Object>) holidayMap.get('date');
                if (dateMap.containsKey('iso')) {
                    holiday.holidayDate = (String) dateMap.get('iso');
                }
            }
            
            holiday.holidayType = 'National';
            holiday.isPrimary = true;
            
            if (String.isBlank(holiday.holidayDate)) {
                continue; // Skip holidays without dates
            }
            
            holidays.add(holiday);
        }
        
        holidays.sort(new HolidayDateComparator());
        return holidays;
    }
    
    /**
     * @description Comparator class to sort holidays by date
     */
    public class HolidayDateComparator implements Comparator<Holiday> {
        public Integer compare(Holiday h1, Holiday h2) {
            if (h1.holidayDate == null && h2.holidayDate == null) return 0;
            if (h1.holidayDate == null) return 1;
            if (h2.holidayDate == null) return -1;
            
            return h1.holidayDate.compareTo(h2.holidayDate);
        }
    }
    
    /**
     * @description Test method to validate API connectivity
     * @return Boolean indicating if API is accessible
     */
    public static Boolean testApiConnectivity() {
        try {
            // Test with current year
            Integer currentYear = Date.today().year();
            HolidayApiResponse response = getHolidaysForYear(currentYear);
            return response.success;
        } catch (Exception e) {
            System.debug('API connectivity test failed: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Future method for asynchronous holiday retrieval
     * @param holidayYear The year to get holidays for
     * @param recordId Optional record ID to update with results
     */
    @future(callout=true)
    public static void getHolidaysAsync(Integer holidayYear, String recordId) {
        HolidayApiResponse response = getHolidaysForYear(holidayYear);
        
        // If we have a record ID, we could store the results
        if (String.isNotBlank(recordId) && response.success) {
            System.debug('Async holiday retrieval completed for record: ' + recordId + 
                        ', found ' + response.holidays.size() + ' holidays');
        }
    }
}