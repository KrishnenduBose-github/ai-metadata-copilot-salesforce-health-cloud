public with sharing class MetadataNaturalLanguageAction {
    public class Request {
        @InvocableVariable(required=true)
        public String userPrompt;

        @InvocableVariable(required=true)
        public String intent;
    }

    public class Response {
        @InvocableVariable
        public String queryType;

        @InvocableVariable
        public String targetApiName;

        @InvocableVariable
        public Decimal confidence;

        @InvocableVariable
        public String reason;
    }

    @InvocableMethod(label='Resolve Metadata Question' description='Grounds a metadata question against the refreshed metadata catalog.')
    public static List<Response> resolve(List<Request> requests) {
        List<Response> results = new List<Response>();
        NaturalLanguageResolutionService resolver = new NaturalLanguageResolutionService();
        for (Request request : requests) {
            AiMetadataCopilotModels.NaturalLanguageInterpretation interpretation =
                resolver.resolve(request.userPrompt, request.intent);
            Response response = new Response();
            response.queryType = interpretation.queryType;
            response.targetApiName = interpretation.targetApiName;
            response.confidence = interpretation.confidence;
            response.reason = interpretation.reason;
            results.add(response);
        }
        return results;
    }
}
