public with sharing class ReleaseNoteGenerationService {
    public AiMetadataCopilotModels.DocumentationResponse generateReleaseNote(
        AiMetadataCopilotModels.DocumentationRequest request
    ) {
        request.requestType = 'ReleaseNote';
        return new MetadataDocumentationService().generate(request);
    }
}
