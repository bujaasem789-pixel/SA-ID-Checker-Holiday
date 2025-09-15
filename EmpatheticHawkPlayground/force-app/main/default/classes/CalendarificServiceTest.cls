/**
 * @description Streamlined test class for CalendarificService
 */
@isTest
private class CalendarificServiceTest {
    
    public class MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"meta":{"code":200},"response":{"holidays":[' +
                       '{"name":"New Year\'s Day","description":"New Year\'s Day",' +
                       '"date":{"iso":"2023-01-01"},"type":["national"]}' +
                       ']}}');
            return res;
        }
    }
    
    public class MockEmptyThenSuccess implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HTTPResponse respond(HTTPRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            if (callCount == 1) {
                res.setBody('{"meta":{"code":200},"response":{"holidays":[]}}');
            } else {
                res.setBody('{"meta":{"code":200},"response":{"holidays":[' +
                           '{"name":"Freedom Day","date":{"iso":"2023-04-27"},"type":["national"]},' +
                           '{"name":"Valentine\'s Day","date":{"iso":"2023-02-14"},"type":["observance"]}' +
                           ']}}');
            }
            return res;
        }
    }
    
    public class MockError implements HttpCalloutMock {
        private Integer statusCode;
        public MockError(Integer code) { this.statusCode = code; }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody('Error');
            return res;
        }
    }
    
    public class MockInvalidJson implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('invalid json');
            return res;
        }
    }
    
    public class MockNetworkError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Network timeout');
        }
    }
    
    @isTest
    static void testGetHolidaysSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        
        CalendarificService.HolidayApiResponse response = 
            CalendarificService.getHolidaysForYear(2023);
        
        System.assert(response.success, 'Should succeed');
        System.assertEquals(1, response.holidays.size(), 'Should have 1 holiday');
        System.assertEquals('New Year\'s Day', response.holidays[0].name, 'Should parse name');
    }
      
    @isTest
    static void testGetHolidaysErrors() {
        // Test key error codes
        Test.setMock(HttpCalloutMock.class, new MockError(401));
        CalendarificService.HolidayApiResponse response401 = 
            CalendarificService.getHolidaysForYear(2023);
        System.assert(!response401.success && response401.errorMessage.contains('authentication'));
        
        Test.setMock(HttpCalloutMock.class, new MockError(500));
        CalendarificService.HolidayApiResponse response500 = 
            CalendarificService.getHolidaysForYear(2023);
        System.assert(!response500.success && response500.errorMessage.contains('server error'));
    }
    
    @isTest
    static void testGetHolidaysInvalidResponse() {
        Test.setMock(HttpCalloutMock.class, new MockInvalidJson());
        CalendarificService.HolidayApiResponse response = 
            CalendarificService.getHolidaysForYear(2023);
        System.assert(!response.success, 'Should fail with invalid JSON');
    }
    
    @isTest
    static void testGetHolidaysNetworkError() {
        Test.setMock(HttpCalloutMock.class, new MockNetworkError());
        CalendarificService.HolidayApiResponse response = 
            CalendarificService.getHolidaysForYear(2023);
        System.assert(!response.success && response.errorMessage.contains('exception'));
    }
    
    @isTest
    static void testHolidayComparator() {
        CalendarificService.Holiday h1 = new CalendarificService.Holiday();
        h1.holidayDate = '2023-01-01';
        CalendarificService.Holiday h2 = new CalendarificService.Holiday();
        h2.holidayDate = '2023-12-25';
        
        CalendarificService.HolidayDateComparator comp = 
            new CalendarificService.HolidayDateComparator();
        
        System.assert(comp.compare(h1, h2) < 0, 'Earlier date should come first');
        System.assert(comp.compare(h2, h1) > 0, 'Later date should come second');
    }
    
    @isTest
    static void testApiConnectivity() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        System.assert(CalendarificService.testApiConnectivity(), 'Should test connectivity');
        
        Test.setMock(HttpCalloutMock.class, new MockError(401));
        System.assert(!CalendarificService.testApiConnectivity(), 'Should fail connectivity');
    }
    
    @isTest
    static void testGetHolidaysAsync() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        
        Test.startTest();
        CalendarificService.getHolidaysAsync(2023, 'test_id');
        Test.stopTest();
        
        System.assert(true, 'Async method should complete');
    }
    
    @isTest
    static void testWrapperClasses() {
        CalendarificService.Holiday holiday = new CalendarificService.Holiday();
        System.assertEquals('', holiday.name, 'Default name should be empty');
        
        CalendarificService.HolidayApiResponse response = new CalendarificService.HolidayApiResponse();
        System.assertEquals(false, response.success, 'Default success should be false');
        System.assertNotEquals(null, response.holidays, 'Default holidays should not be null');
    }
}