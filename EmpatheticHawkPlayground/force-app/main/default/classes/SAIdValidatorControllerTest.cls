/**
 * @description Streamlined test class for SAIdValidatorController
 */
@isTest
private class SAIdValidatorControllerTest {
    
   /* public class MockApiSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"meta":{"code":200},"response":{"holidays":[' +
                       '{"name":"New Year\'s Day","description":"New Year\'s Day","date":{"iso":"1980-01-01"},"type":["national"]},' +
                       '{"name":"Christmas Day","description":"Christmas Day","date":{"iso":"1980-12-25"},"type":["national"]}' +
                       ']}}');
            return res;
        }
    }*/
    
    /*public class MockApiFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error":"Unauthorized"}');
            return res;
        }
    }*/
    
    @testSetup
    static void setup() {
        insert new SA_ID_Search__c(
            SA_ID_Number__c = '8001015009087',
            Date_of_Birth__c = Date.newInstance(1980, 1, 1),
            Gender__c = 'Male',
            SA_Citizen__c = true,
            Birth_Year__c = 1980,
            Search_Count__c = 1,
            Last_Search_Date__c = System.now().addDays(-1)
        );
    }
    
    @isTest
    static void testValidateAndSearchSuccess() {
       /* Test.setMock(HttpCalloutMock.class, new MockApiSuccess());
        */
        Test.startTest();
        SAIdValidatorController.SearchResult result = 
            SAIdValidatorController.validateAndSearch('8001015009087');
        Test.stopTest();
        
        System.assert(result.isValid, 'Result should be valid');
        System.assertEquals(1980, result.idDetails.birthYear, 'Should extract birth year');
        System.assertEquals('Male', result.idDetails.gender, 'Should extract gender');
        System.assertEquals(2, result.searchCount, 'Should increment search count');
    }
    
    @isTest
    static void testValidateAndSearchInvalid() {
        SAIdValidatorController.SearchResult result = 
            SAIdValidatorController.validateAndSearch('1234567890123');
        
        System.assert(!result.isValid, 'Invalid ID should fail');
        System.assert(result.errorMessage.contains('Invalid'), 'Should have error message');
    }
    
    @isTest
    static void testValidateAndSearchEdgeCases() {
        SAIdValidatorController.SearchResult resultNull = 
            SAIdValidatorController.validateAndSearch(null);
        System.assert(!resultNull.isValid, 'Null should be invalid');
        
        SAIdValidatorController.SearchResult resultEmpty = 
            SAIdValidatorController.validateAndSearch('');
        System.assert(!resultEmpty.isValid, 'Empty should be invalid');
    }
    
    @isTest
    static void testValidateIdFormat() {
        System.assert(SAIdValidatorController.validateIdFormat('8001015009087'), 'Valid ID should return true');
        System.assert(!SAIdValidatorController.validateIdFormat('invalid'), 'Invalid should return false');
        System.assert(!SAIdValidatorController.validateIdFormat(null), 'Null should return false');
    }
    
}