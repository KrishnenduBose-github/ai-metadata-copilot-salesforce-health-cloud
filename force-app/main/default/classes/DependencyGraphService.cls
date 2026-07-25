public with sharing class DependencyGraphService {
    private class UsageLink {
        String sourceKey;
        String targetKey;
        String usageType;
        String sourceType;
        String targetType;
        String matchText;
        String contextSnippet;
    }

    public AiMetadataCopilotModels.DependencyGraphResponse buildForQuery(
        String queryText,
        String queryType,
        Integer requestedDepth,
        String direction,
        List<String> metadataTypes,
        Boolean hideLowConfidence
    ) {
        String rootKey = 'ObjectUsage' == queryType
            ? 'Object:' + safeText(queryText)
            : 'CustomField:' + safeText(queryText);
        return build(rootKey, requestedDepth, direction, metadataTypes, hideLowConfidence);
    }

    public AiMetadataCopilotModels.DependencyGraphResponse build(
        String rootKey,
        Integer requestedDepth,
        String direction,
        List<String> metadataTypes,
        Boolean hideLowConfidence
    ) {
        AiMetadataCopilotModels.DependencyGraphResponse response =
            new AiMetadataCopilotModels.DependencyGraphResponse();
        response.rootKey = rootKey;
        response.rootLabel = displayName(rootKey);
        response.nodes = new List<AiMetadataCopilotModels.DependencyGraphNode>();
        response.edges = new List<AiMetadataCopilotModels.DependencyGraphEdge>();
        response.warnings = new List<String>();
        response.maxDepth = normalizeDepth(requestedDepth);
        response.complete = true;

        if (String.isBlank(rootKey) || !Schema.sObjectType.Metadata_Usage__c.isAccessible()) {
            response.complete = false;
            response.warnings.add('Dependency relationships are unavailable because Metadata Usage access is missing.');
            return response;
        }

        Map<String, List<UsageLink>> outbound = new Map<String, List<UsageLink>>();
        Map<String, List<UsageLink>> inbound = new Map<String, List<UsageLink>>();
        Set<String> allKeys = new Set<String>{ rootKey };
        for (Metadata_Usage__c record : [
            SELECT Source_Key__c, Source_Type__c, Target_Key__c, Target_Type__c,
                   Usage_Type__c, Match_Text__c, Context_Snippet__c
            FROM Metadata_Usage__c
            WHERE Source_Key__c != null AND Target_Key__c != null
            LIMIT 10000
        ]) {
            UsageLink link = new UsageLink();
            link.sourceKey = record.Source_Key__c;
            link.targetKey = record.Target_Key__c;
            link.usageType = record.Usage_Type__c;
            link.sourceType = record.Source_Type__c;
            link.targetType = record.Target_Type__c;
            link.matchText = record.Match_Text__c;
            link.contextSnippet = record.Context_Snippet__c;
            addLink(outbound, link.sourceKey, link);
            addLink(inbound, link.targetKey, link);
            allKeys.add(link.sourceKey);
            allKeys.add(link.targetKey);
        }

        Map<String, Metadata_Item__c> itemsByKey = loadItems(allKeys);
        Map<String, Integer> depthByKey = new Map<String, Integer>{ rootKey => 0 };
        Map<String, String> directionByKey = new Map<String, String>{ rootKey => 'Root' };
        List<String> queue = new List<String>{ rootKey };
        Set<String> edgeKeys = new Set<String>();
        Set<String> selectedTypes = normalizeSet(metadataTypes);
        Set<String> lowConfidence = new Set<String>{ 'TextMatch', 'Inferred' };

        while (!queue.isEmpty()) {
            String currentKey = queue.remove(0);
            Integer currentDepth = depthByKey.get(currentKey);
            if (currentDepth >= response.maxDepth) {
                continue;
            }

            List<UsageLink> links = new List<UsageLink>();
            if (direction == 'DependsOn' || direction == 'Both' || String.isBlank(direction)) {
                links.addAll(outbound.containsKey(currentKey) ? outbound.get(currentKey) : new List<UsageLink>());
            }
            if (direction == 'ReferencedBy' || direction == 'Both' || String.isBlank(direction)) {
                links.addAll(inbound.containsKey(currentKey) ? inbound.get(currentKey) : new List<UsageLink>());
            }

            for (UsageLink link : links) {
                String neighborKey = link.sourceKey == currentKey ? link.targetKey : link.sourceKey;
                String neighborType = link.sourceKey == currentKey ? link.targetType : link.sourceType;
                if (!selectedTypes.isEmpty() && !selectedTypes.contains(neighborType)) {
                    continue;
                }

                String confidence = confidenceFor(link);
                if (hideLowConfidence == true && lowConfidence.contains(confidence)) {
                    continue;
                }

                String edgeKey = link.sourceKey + '|' + link.targetKey + '|' + link.usageType;
                if (!edgeKeys.contains(edgeKey)) {
                    edgeKeys.add(edgeKey);
                    AiMetadataCopilotModels.DependencyGraphEdge edge =
                        new AiMetadataCopilotModels.DependencyGraphEdge();
                    edge.key = edgeKey;
                    edge.sourceKey = link.sourceKey;
                    edge.targetKey = link.targetKey;
                    edge.relationshipType = link.usageType;
                    edge.direction = link.sourceKey == currentKey ? 'DependsOn' : 'ReferencedBy';
                    edge.confidence = confidence;
                    edge.evidence = safeText(link.contextSnippet);
                    response.edges.add(edge);
                }

                if (!depthByKey.containsKey(neighborKey)) {
                    depthByKey.put(neighborKey, currentDepth + 1);
                    directionByKey.put(neighborKey, link.sourceKey == currentKey ? 'DependsOn' : 'ReferencedBy');
                    queue.add(neighborKey);
                }
            }
        }

        for (String key : depthByKey.keySet()) {
            Metadata_Item__c item = itemsByKey.get(key);
            UsageLink evidenceLink = findEvidence(key, outbound, inbound);
            AiMetadataCopilotModels.DependencyGraphNode node = new AiMetadataCopilotModels.DependencyGraphNode();
            node.key = key;
            node.label = item == null ? displayName(key) : item.Name;
            node.apiName = item == null ? displayName(key) : item.Api_Name__c;
            node.metadataType = item == null ? typeFromKey(key) : item.Metadata_Type__c;
            node.category = categoryFor(node.metadataType);
            node.depth = depthByKey.get(key);
            node.direction = directionByKey.get(key);
            node.confidence = key == rootKey ? 'Root' : confidenceFor(evidenceLink);
            node.evidence = evidenceLink == null ? 'Root metadata target.' : safeText(evidenceLink.contextSnippet);
            node.lastIndexedOn = item == null ? null : item.Last_Indexed_On__c;
            response.nodes.add(node);
        }

        response.directDependencyCount = countAtDepth(depthByKey, 1);
        response.transitiveDependencyCount = depthByKey.size() - response.directDependencyCount - 1;
        if (response.transitiveDependencyCount < 0) {
            response.transitiveDependencyCount = 0;
        }
        if (response.edges.size() >= 10000) {
            response.complete = false;
            response.warnings.add('The graph reached the 10,000 relationship safety limit. Narrow the filters or depth.');
        }
        response.warnings.add('Current indexed coverage is strongest for ApexClass, Flow, and CustomField relationships.');
        return response;
    }

    private static Map<String, Metadata_Item__c> loadItems(Set<String> keys) {
        Map<String, Metadata_Item__c> itemsByKey = new Map<String, Metadata_Item__c>();
        if (keys.isEmpty() || !Schema.sObjectType.Metadata_Item__c.isAccessible()) {
            return itemsByKey;
        }
        for (Metadata_Item__c item : [
            SELECT Metadata_Key__c, Name, Api_Name__c, Metadata_Type__c, Last_Indexed_On__c
            FROM Metadata_Item__c
            WHERE Metadata_Key__c IN :keys
        ]) {
            itemsByKey.put(item.Metadata_Key__c, item);
        }
        return itemsByKey;
    }

    private static void addLink(Map<String, List<UsageLink>> linksByKey, String key, UsageLink link) {
        if (!linksByKey.containsKey(key)) {
            linksByKey.put(key, new List<UsageLink>());
        }
        linksByKey.get(key).add(link);
    }

    private static UsageLink findEvidence(
        String key,
        Map<String, List<UsageLink>> outbound,
        Map<String, List<UsageLink>> inbound
    ) {
        if (outbound.containsKey(key) && !outbound.get(key).isEmpty()) return outbound.get(key)[0];
        if (inbound.containsKey(key) && !inbound.get(key).isEmpty()) return inbound.get(key)[0];
        return null;
    }

    private static Integer countAtDepth(Map<String, Integer> depthByKey, Integer requestedDepth) {
        Integer count = 0;
        for (Integer depth : depthByKey.values()) {
            if (depth == requestedDepth) count++;
        }
        return count;
    }

    private static Set<String> normalizeSet(List<String> values) {
        Set<String> result = new Set<String>();
        if (values == null) return result;
        for (String value : values) {
            if (!String.isBlank(value)) result.add(value.trim());
        }
        return result;
    }

    private static Integer normalizeDepth(Integer requestedDepth) {
        if (requestedDepth == null || requestedDepth < 1) return 2;
        return Math.min(requestedDepth, 3);
    }

    private static String confidenceFor(UsageLink link) {
        return link == null ? 'Inferred' : 'TextMatch';
    }

    private static String categoryFor(String metadataType) {
        if (metadataType == 'Flow') return 'Automation';
        if (metadataType == 'ApexClass' || metadataType == 'ApexTrigger') return 'Code';
        if (metadataType == 'PermissionSet' || metadataType == 'Profile') return 'Security';
        if (metadataType == 'Report' || metadataType == 'Dashboard') return 'Reporting';
        if (metadataType == 'LWC' || metadataType == 'OmniScript' || metadataType == 'Layout') return 'User Interface';
        if (metadataType == 'CustomField' || metadataType == 'CustomObject') return 'Data Model';
        return 'Other';
    }

    private static String typeFromKey(String key) {
        return String.isBlank(key) || !key.contains(':') ? 'Unknown' : key.substringBefore(':');
    }

    private static String displayName(String key) {
        return String.isBlank(key) || !key.contains(':') ? safeText(key) : key.substringAfter(':');
    }

    private static String safeText(String value) {
        return String.isBlank(value) ? 'Unknown metadata' : value.trim();
    }
}
