public with sharing class MetadataToolingApiClient {
    /*
     * Beginner-friendly note:
     * This class calls the Salesforce Tooling API by using a Named Credential.
     * This is the safer and more reliable approach for LWC-driven Apex because
     * Lightning session IDs do not have REST API access.
     */

    public class ToolingQueryResult {
        public Integer totalSize;
        public Boolean done;
        public String nextRecordsUrl;
        public List<Object> records;
    }

    public class ToolingApiException extends Exception {}

    @TestVisible
    private static final String NAMED_CREDENTIAL = 'callout:SalesforceTooling';

    @TestVisible
    private static final String API_VERSION = 'v61.0';

    public virtual ToolingQueryResult runQuery(String toolingSoql) {
        validateQuery(toolingSoql);

        String encodedQuery = EncodingUtil.urlEncode(toolingSoql, 'UTF-8');
        String endpoint = NAMED_CREDENTIAL
            + '/services/data/'
            + API_VERSION
            + '/tooling/query/?q='
            + encodedQuery;

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(120000);

        Http http = new Http();
        HttpResponse response;

        try {
            response = http.send(request);
        } catch (System.CalloutException calloutError) {
            throw new ToolingApiException(
                'Tooling API callout failed. Verify the Named Credential SalesforceTooling is configured. '
                + calloutError.getMessage()
            );
        }

        return parseResponse(response);
    }

    private static void validateQuery(String toolingSoql) {
        if (String.isBlank(toolingSoql)) {
            throw new ToolingApiException('Tooling SOQL query cannot be blank.');
        }
    }

    private static ToolingQueryResult parseResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();

        if (statusCode < 200 || statusCode >= 300) {
            throw new ToolingApiException(
                'Tooling API request failed. Status: '
                + statusCode
                + '. Body: '
                + response.getBody()
            );
        }

        Map<String, Object> rawResult = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
        );

        ToolingQueryResult result = new ToolingQueryResult();
        result.totalSize = (Integer) rawResult.get('totalSize');
        result.done = (Boolean) rawResult.get('done');
        result.nextRecordsUrl = (String) rawResult.get('nextRecordsUrl');
        result.records = (List<Object>) rawResult.get('records');

        return result;
    }
}
