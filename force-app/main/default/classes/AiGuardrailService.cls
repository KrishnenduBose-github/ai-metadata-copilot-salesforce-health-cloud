public with sharing class AiGuardrailService {
    public void validateReadOnlyPrompt(String userPrompt) {
        String normalizedPrompt = String.isBlank(userPrompt) ? '' : userPrompt.toLowerCase();
        List<String> blockedPhrases = new List<String>{
            'delete records',
            'update data',
            'change permissions',
            'disable security',
            'bypass fls'
        };

        for (String blockedPhrase : blockedPhrases) {
            if (normalizedPrompt.contains(blockedPhrase)) {
                throw new AuraHandledException(
                    'AI Metadata Copilot is read-only and cannot perform destructive or unsafe actions.'
                );
            }
        }
    }

    public String redactSensitiveWording(String inputText) {
        if (String.isBlank(inputText)) {
            return inputText;
        }

        String redactedValue = inputText.replace('patient value', 'patient field');
        redactedValue = redactedValue.replace('claim amount value', 'claim field');
        return redactedValue;
    }
}
