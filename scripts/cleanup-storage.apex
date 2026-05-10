List<String> objectNames = new List<String>{
    'Metadata_Usage__c',
    'Metadata_Component_Version__c',
    'Optimization_Finding__c',
    'Documentation_Request__c',
    'Deployment_Finding__c',
    'Impact_Assessment__c',
    'Deployment_Assessment__c',
    'Security_Finding__c',
    'Security_Audit_Run__c',
    'Metadata_Snapshot__c',
    'Metadata_Item__c'
};

Integer totalDeleted = 0;
for (String objName : objectNames) {
    Integer count = Database.countQuery('SELECT COUNT() FROM ' + objName);
    if (count == 0) {
        System.debug('Skipped ' + objName + ': no records.');
        continue;
    }
    List<SObject> records = Database.query('SELECT Id FROM ' + objName + ' LIMIT 10000');
    Database.DeleteResult[] results = Database.delete(records, false);
    Integer deleted = 0;
    Integer failed = 0;
    for (Database.DeleteResult dr : results) {
        if (dr.isSuccess()) {
            deleted++;
        } else {
            failed++;
        }
    }
    totalDeleted += deleted;
    String msg = objName + ': ' + count + ' found, ' + deleted + ' deleted';
    if (failed > 0) {
        msg += ', ' + failed + ' failed';
    }
    System.debug(msg);
}
System.debug('Total records deleted: ' + totalDeleted);
