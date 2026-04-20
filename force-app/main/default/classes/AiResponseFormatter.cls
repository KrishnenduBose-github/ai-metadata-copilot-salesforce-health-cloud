public with sharing class AiResponseFormatter {
    public Decimal toScore(Integer count, Integer multiplier, Integer maxScore) {
        Integer rawScore = count * multiplier;
        return rawScore > maxScore ? maxScore : rawScore;
    }

    public String severityFromScore(Decimal score) {
        if (score >= 85) {
            return 'Critical';
        }

        if (score >= 60) {
            return 'High';
        }

        if (score >= 30) {
            return 'Medium';
        }

        return 'Low';
    }
}
