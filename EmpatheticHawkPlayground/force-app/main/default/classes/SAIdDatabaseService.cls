/**
 * @description Database service class for SA ID Search records
 * @author CloudSmiths Technical Assignment
 */
public with sharing class SAIdDatabaseService {
    
    /**
     * @description Creates or updates SA ID search record with decoded information
     * @param idNumber The SA ID number
     * @param details The decoded ID details
     * @return SA_ID_Search__c record that was created or updated
     */
    public static SA_ID_Search__c upsertSAIdRecord(String idNumber, SAIdValidator.IdDetails details) {
        try {
            SA_ID_Search__c searchRecord = new SA_ID_Search__c();
            searchRecord.SA_ID_Number__c = idNumber;
            searchRecord.Date_of_Birth__c = details.dateOfBirth;
            searchRecord.Gender__c = details.gender;
            searchRecord.SA_Citizen__c = details.isSACitizen;
            searchRecord.Birth_Year__c = details.birthYear;
            searchRecord.Last_Search_Date__c = System.now();
            
            // Check if record already exists
            List<SA_ID_Search__c> existingRecords = [
                SELECT Id, Search_Count__c 
                FROM SA_ID_Search__c 
                WHERE SA_ID_Number__c = :idNumber 
                LIMIT 1
            ];
            
            if (!existingRecords.isEmpty()) {
                // Update existing record
                searchRecord.Id = existingRecords[0].Id;
                searchRecord.Search_Count__c = (existingRecords[0].Search_Count__c != null) 
                    ? existingRecords[0].Search_Count__c + 1 
                    : 1;
            } else {
                // New record
                searchRecord.Search_Count__c = 1;
            }
            
            upsert searchRecord SA_ID_Number__c;
            
            System.debug('Successfully upserted SA ID record: ' + searchRecord.Id);
            return searchRecord;
            
        } catch (Exception e) {
            System.debug('Error upserting SA ID record: ' + e.getMessage());
            throw new DatabaseException('Failed to save SA ID record: ' + e.getMessage());
        }
    }
    
    /**
     * @description Retrieves SA ID search record by ID number
     * @param idNumber The SA ID number to search for
     * @return SA_ID_Search__c record if found, null otherwise
     */
    public static SA_ID_Search__c getSAIdRecord(String idNumber) {
        try {
            List<SA_ID_Search__c> records = [
                SELECT Id, SA_ID_Number__c, Date_of_Birth__c, Gender__c, 
                       SA_Citizen__c, Birth_Year__c, Search_Count__c, Last_Search_Date__c
                FROM SA_ID_Search__c 
                WHERE SA_ID_Number__c = :idNumber 
                LIMIT 1
            ];
            
            return records.isEmpty() ? null : records[0];
            
        } catch (Exception e) {
            System.debug('Error retrieving SA ID record: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Retrieves search statistics for reporting
     * @return Map with search statistics
     */
    public static Map<String, Object> getSearchStatistics() {
        Map<String, Object> stats = new Map<String, Object>();
        
        try {
            // Total unique IDs searched
            Integer totalUniqueSearches = [SELECT COUNT() FROM SA_ID_Search__c];
            
            // Total search count across all IDs
            AggregateResult totalSearchResult = [
                SELECT SUM(Search_Count__c) totalSearches 
                FROM SA_ID_Search__c
            ][0];
            
            Integer totalSearches = (Integer)totalSearchResult.get('totalSearches');
            
            // Most searched ID
            List<SA_ID_Search__c> mostSearched = [
                SELECT SA_ID_Number__c, Search_Count__c 
                FROM SA_ID_Search__c 
                ORDER BY Search_Count__c DESC 
                LIMIT 1
            ];
            
            // Recent searches
            List<SA_ID_Search__c> recentSearches = [
                SELECT SA_ID_Number__c, Last_Search_Date__c, Search_Count__c
                FROM SA_ID_Search__c 
                ORDER BY Last_Search_Date__c DESC 
                LIMIT 5
            ];
            
            stats.put('totalUniqueSearches', totalUniqueSearches);
            stats.put('totalSearches', totalSearches != null ? totalSearches : 0);
            stats.put('mostSearchedId', mostSearched.isEmpty() ? null : mostSearched[0]);
            stats.put('recentSearches', recentSearches);
            
        } catch (Exception e) {
            System.debug('Error retrieving search statistics: ' + e.getMessage());
        }
        
        return stats;
    }
    
    /**
     * @description Custom exception for database operations
     */
    public class DatabaseException extends Exception {}
}