import { LightningElement } from 'lwc';
import refreshMetadataIndex from '@salesforce/apex/AiMetadataCopilotController.refreshMetadataIndex';
import searchMetadata from '@salesforce/apex/AiMetadataCopilotController.searchMetadata';
import searchMetadataDirect from '@salesforce/apex/AiMetadataCopilotController.searchMetadataDirect';
import searchMetadataDirectFiltered from '@salesforce/apex/AiMetadataCopilotController.searchMetadataDirectFiltered';
import analyzeImpact from '@salesforce/apex/AiMetadataCopilotController.analyzeImpact';
import analyzeImpactDirect from '@salesforce/apex/AiMetadataCopilotController.analyzeImpactDirect';
import getDependencyGraph from '@salesforce/apex/AiMetadataCopilotController.getDependencyGraph';
import runSecurityAudit from '@salesforce/apex/AiMetadataCopilotController.runSecurityAudit';
import runSecurityAuditDirect from '@salesforce/apex/AiMetadataCopilotController.runSecurityAuditDirect';
import compareEnvironments from '@salesforce/apex/AiMetadataCopilotController.compareEnvironments';
import getDeploymentWorkspaceState from '@salesforce/apex/AiMetadataCopilotController.getDeploymentWorkspaceState';
import captureDeploymentSnapshot from '@salesforce/apex/AiMetadataCopilotController.captureDeploymentSnapshot';
import captureAndCompareDeployment from '@salesforce/apex/AiMetadataCopilotController.captureAndCompareDeployment';
import runOptimizationScan from '@salesforce/apex/AiMetadataCopilotController.runOptimizationScan';
import checkHealth from '@salesforce/apex/AiMetadataCopilotController.checkHealth';

export default class AiMetadataCopilotWorkspace extends LightningElement {
    activeTab = 'search';
    isLoading = false;
    errorMessage = '';

    searchMode = 'simple';
    impactMode = 'simple';
    searchPrompt = '';
    impactPrompt = '';
    searchQueryText = '';
    searchQueryType = 'FieldUsage';
    searchSourceMetadataTypes = [];
    searchUsageTypes = [];
    impactQueryText = '';
    impactQueryType = 'FieldUsage';
    impactDepth = '2';
    impactDirection = 'Both';
    impactMetadataTypes = [];
    hideLowConfidence = false;
    selectedGraphNode;
    securityPrompt = '';
    safetyFilter = true;
    sourceEnvironment = 'Current Sandbox';
    targetEnvironment = 'Previous Snapshot';
    baselineLabel = 'Release Baseline';
    currentSnapshotLabel = 'Current State';
    selectedBaselineKey = '';
    selectedTargetKey = '';

    searchResponse;
    impactResponse;
    securityResponse;
    deploymentResponse;
    optimizationResponse;
    healthStatus;
    refreshResult;
    deploymentState;

    queryTypeOptions = [
        { label: 'Field Usage', value: 'FieldUsage' },
        { label: 'Object Usage', value: 'ObjectUsage' }
    ];

    modeOptions = [
        { label: 'Direct API Name', value: 'simple' },
        { label: 'Natural Language', value: 'natural' }
    ];

    searchColumns = [
        { label: 'Source Name', fieldName: 'metadataName' },
        { label: 'Metadata Type', fieldName: 'metadataType' },
        { label: 'Usage Type', fieldName: 'usageType' },
        { label: 'Target', fieldName: 'metadataKey' },
        { label: 'Context', fieldName: 'context' }
    ];

    securityColumns = [
        { label: 'Finding Type', fieldName: 'findingType' },
        { label: 'Severity', fieldName: 'severity' },
        { label: 'Object', fieldName: 'objectApiName' },
        { label: 'Field', fieldName: 'fieldApiName' },
        { label: 'Permission', fieldName: 'permissionArtifact' },
        { label: 'Summary', fieldName: 'summary' }
    ];

    deploymentColumns = [
        { label: 'Finding Type', fieldName: 'findingType' },
        { label: 'Severity', fieldName: 'severity' },
        { label: 'Metadata Key', fieldName: 'metadataKey' },
        { label: 'Summary', fieldName: 'summary' },
        { label: 'Recommendation', fieldName: 'recommendation' }
    ];

    optimizationColumns = [
        { label: 'Finding Type', fieldName: 'findingType' },
        { label: 'Severity', fieldName: 'severity' },
        { label: 'Metadata Key', fieldName: 'metadataKey' },
        { label: 'Summary', fieldName: 'summary' }
    ];

    indexedMetadataTypes = [
        { label: 'Apex', value: 'ApexClass' },
        { label: 'Flow', value: 'Flow' },
        { label: 'Custom Field', value: 'CustomField' }
    ];

    indexedUsageTypes = [
        { label: 'Uses Field', value: 'UsesField' },
        { label: 'Uses Object', value: 'UsesObject' },
        { label: 'Invokes Flow', value: 'InvokesFlow' },
        { label: 'Has Permission', value: 'HasPermission' }
    ];

    impactDepthOptions = [
        { label: '1 level', value: '1' },
        { label: '2 levels', value: '2' },
        { label: '3 levels', value: '3' }
    ];

    impactDirectionOptions = [
        { label: 'Both directions', value: 'Both' },
        { label: 'Referenced by', value: 'ReferencedBy' },
        { label: 'Depends on', value: 'DependsOn' }
    ];

    get hasSearchResults() {
        return this.searchResponse && this.searchResponse.matchedComponents && this.searchResponse.matchedComponents.length > 0;
    }

    get searchInterpretation() {
        return this.searchResponse && this.searchResponse.interpretation;
    }

    get impactInterpretation() {
        return this.impactResponse && this.impactResponse.interpretation;
    }

    get searchInterpretationText() {
        const interpretation = this.searchInterpretation;
        if (!interpretation) return '';
        if (interpretation.targetApiName) {
            return `Searching ${interpretation.queryType || 'metadata'} for ${interpretation.targetApiName} (${interpretation.resolutionMethod || 'catalog'}).`;
        }
        return interpretation.reason || 'No metadata target was resolved.';
    }

    get impactInterpretationText() {
        const interpretation = this.impactInterpretation;
        if (!interpretation) return '';
        if (interpretation.targetApiName) {
            return `Analyzing ${interpretation.queryType || 'metadata'} for ${interpretation.targetApiName} (${interpretation.resolutionMethod || 'catalog'}).`;
        }
        return interpretation.reason || 'No metadata target was resolved.';
    }

    get hasImpactResults() {
        return this.impactResponse && this.impactResponse.impactedComponents && this.impactResponse.impactedComponents.length > 0;
    }

    get searchSourceFilterOptions() {
        return this.withCounts(this.indexedMetadataTypes, this.searchResponse && this.searchResponse.sourceTypeCounts);
    }

    get searchUsageFilterOptions() {
        return this.withCounts(this.indexedUsageTypes, this.searchResponse && this.searchResponse.usageTypeCounts);
    }

    get indexedCoverageText() {
        return this.searchResponse && this.searchResponse.indexedCoverage
            ? this.searchResponse.indexedCoverage.join(', ')
            : 'ApexClass, Flow, CustomField';
    }

    get impactGraph() {
        return this.impactResponse && this.impactResponse.dependencyGraph;
    }

    get hasImpactGraph() {
        return Boolean(this.impactGraph && this.impactGraph.nodes && this.impactGraph.nodes.length > 0);
    }

    get graphLevels() {
        if (!this.hasImpactGraph) return [];
        const levels = [];
        const maxDepth = this.impactGraph.maxDepth || 0;
        for (let depth = 0; depth <= maxDepth; depth += 1) {
            const nodes = this.impactGraph.nodes.filter((node) => node.depth === depth);
            if (nodes.length) levels.push({ depth, label: depth === 0 ? 'Selected metadata' : `Dependency level ${depth}`, nodes });
        }
        return levels;
    }

    get graphEdges() {
        if (!this.hasImpactGraph || !this.impactGraph.edges) return [];
        const labelByKey = new Map(this.impactGraph.nodes.map((node) => [node.key, node.label]));
        return this.impactGraph.edges.map((edge) => ({
            ...edge,
            sourceLabel: labelByKey.get(edge.sourceKey) || edge.sourceKey,
            targetLabel: labelByKey.get(edge.targetKey) || edge.targetKey
        }));
    }

    get hasSelectedGraphNode() {
        return Boolean(this.selectedGraphNode);
    }

    get selectedGraphNodeDirection() {
        return this.selectedGraphNode ? this.selectedGraphNode.direction : '';
    }

    get hasSecurityResults() {
        return this.securityResponse && this.securityResponse.findings && this.securityResponse.findings.length > 0;
    }

    get hasDeploymentResults() {
        return this.deploymentResponse && this.deploymentResponse.findings && this.deploymentResponse.findings.length > 0;
    }

    get deploymentSnapshots() {
        return this.deploymentState && this.deploymentState.snapshots
            ? this.deploymentState.snapshots
            : [];
    }

    get deploymentSnapshotOptions() {
        return this.deploymentSnapshots.map((snapshot) => ({
            label: `${snapshot.label} | ${snapshot.componentCount} items | ${this.formatDate(snapshot.capturedOn)}`,
            value: snapshot.snapshotKey
        }));
    }

    get hasDeploymentSnapshots() {
        return this.deploymentSnapshots.length > 0;
    }

    get hasDeploymentPair() {
        return Boolean(this.selectedBaselineKey && this.selectedTargetKey);
    }

    get deploymentStateMessage() {
        if (!this.deploymentState) return 'Loading release snapshots...';
        return this.deploymentState.setupMessage || '';
    }

    get hasOptimizationResults() {
        return this.optimizationResponse && this.optimizationResponse.findings && this.optimizationResponse.findings.length > 0;
    }

    get healthSummary() {
        if (!this.healthStatus) return 'Loading...';
        const h = this.healthStatus;
        return `Items: ${h.indexedItemCount || 0} | Relationships: ${h.usageRecordCount || 0} | Snapshots: ${h.snapshotCount || 0}`;
    }

    get refreshStatusClass() {
        if (!this.refreshResult) return 'alert alert-success';
        return this.refreshResult.status === 'Success' ? 'alert alert-success' : 'alert alert-warn';
    }

    get refreshSummary() {
        if (!this.refreshResult) return '';
        const status = this.refreshResult.status || 'Success';
        return `${status}: ${this.refreshResult.indexedItems || 0} indexed, ${this.refreshResult.usageRelationships || 0} relationships`;
    }

    get refreshWarning() {
        return this.refreshResult && this.refreshResult.warningSummary ? this.refreshResult.warningSummary : '';
    }

    get isSearchSimple() { return this.searchMode === 'simple'; }
    get isImpactSimple() { return this.impactMode === 'simple'; }

    connectedCallback() {
        this.loadHealthStatus();
        this.loadDeploymentState();
    }

    handleTabChange(event) {
        this.activeTab = event.target.value;
        if (this.activeTab === 'deployment') this.loadDeploymentState();
    }
    handleSearchModeChange(event) { this.searchMode = this.readInput(event); }
    handleImpactModeChange(event) { this.impactMode = this.readInput(event); }

    handleSearchPromptChange(event) { this.searchPrompt = this.readInput(event); }
    handleImpactPromptChange(event) { this.impactPrompt = this.readInput(event); }
    handleSearchQueryTextChange(event) { this.searchQueryText = this.readInput(event); }
    handleSearchQueryTypeChange(event) { this.searchQueryType = this.readInput(event); }
    handleSearchSourceTypeChange(event) { this.searchSourceMetadataTypes = this.readInput(event) || []; }
    handleSearchUsageTypeChange(event) { this.searchUsageTypes = this.readInput(event) || []; }
    handleImpactQueryTextChange(event) { this.impactQueryText = this.readInput(event); }
    handleImpactQueryTypeChange(event) { this.impactQueryType = this.readInput(event); }
    handleImpactDepthChange(event) { this.impactDepth = this.readInput(event); }
    handleImpactDirectionChange(event) { this.impactDirection = this.readInput(event); }
    handleImpactMetadataTypeChange(event) { this.impactMetadataTypes = this.readInput(event) || []; }
    handleHideLowConfidenceChange(event) { this.hideLowConfidence = event.target.checked; }
    handleSecurityPromptChange(event) { this.securityPrompt = this.readInput(event); }
    handleSourceEnvChange(event) { this.sourceEnvironment = this.readInput(event); }
    handleTargetEnvChange(event) { this.targetEnvironment = this.readInput(event); }
    handleBaselineLabelChange(event) { this.baselineLabel = this.readInput(event); }
    handleCurrentSnapshotLabelChange(event) { this.currentSnapshotLabel = this.readInput(event); }
    handleBaselineChange(event) { this.selectedBaselineKey = this.readInput(event); }
    handleTargetSnapshotChange(event) { this.selectedTargetKey = this.readInput(event); }

    readInput(event) {
        if (event && event.detail && event.detail.value !== undefined) return event.detail.value;
        return event && event.target ? event.target.value : '';
    }

    readField(fieldName, fallbackValue) {
        const input = this.template.querySelector(`[data-field="${fieldName}"]`);
        if (input && input.value !== undefined) return input.value;
        return fallbackValue || '';
    }

    syncCurrentInputs() {
        this.searchPrompt = this.readField('searchPrompt', this.searchPrompt);
        this.impactPrompt = this.readField('impactPrompt', this.impactPrompt);
        this.searchQueryText = this.readField('searchQueryText', this.searchQueryText);
        this.searchQueryType = this.readField('searchQueryType', this.searchQueryType);
        this.searchSourceMetadataTypes = this.readField('searchSourceMetadataTypes', this.searchSourceMetadataTypes);
        this.searchUsageTypes = this.readField('searchUsageTypes', this.searchUsageTypes);
        this.impactQueryText = this.readField('impactQueryText', this.impactQueryText);
        this.impactQueryType = this.readField('impactQueryType', this.impactQueryType);
        this.securityPrompt = this.readField('securityPrompt', this.securityPrompt);
        this.sourceEnvironment = this.readField('sourceEnvironment', this.sourceEnvironment);
        this.targetEnvironment = this.readField('targetEnvironment', this.targetEnvironment);
    }

    async loadHealthStatus() {
        try {
            this.healthStatus = await checkHealth();
        } catch (error) {
            this.healthStatus = { isHealthy: false, indexedItemCount: 0, usageRecordCount: 0, warnings: [this.reduceError(error)], recommendations: [] };
        }
    }

    async loadDeploymentState() {
        try {
            this.deploymentState = await getDeploymentWorkspaceState();
            const snapshots = this.deploymentSnapshots;
            if (!this.selectedBaselineKey && snapshots.length > 0) {
                this.selectedBaselineKey = snapshots[0].snapshotKey;
            }
            if (!this.selectedTargetKey && snapshots.length > 1) {
                this.selectedTargetKey = snapshots[1].snapshotKey;
            }
        } catch (error) {
            this.deploymentState = {
                snapshotStorageReady: false,
                setupMessage: this.reduceError(error),
                snapshots: []
            };
        }
    }

    async handleRefresh() {
        this.refreshResult = null;
        await this.runOp(async () => {
            this.refreshResult = await refreshMetadataIndex();
        });
        await this.loadHealthStatus();
    }

    async handleSearch() {
        await this.runOp(async () => {
            this.syncCurrentInputs();
            if (this.isSearchSimple) {
                const queryText = this.searchQueryText ? this.searchQueryText.trim() : '';
                if (!queryText) {
                    throw new Error('Enter a field or object API name.');
                }
                this.searchResponse = await searchMetadataDirectFiltered({
                    queryText,
                    queryType: this.searchQueryType,
                    sourceMetadataTypes: this.searchSourceMetadataTypes,
                    usageTypes: this.searchUsageTypes
                });
            } else {
                const userPrompt = this.searchPrompt ? this.searchPrompt.trim() : '';
                if (!userPrompt) {
                    throw new Error('Enter a metadata question.');
                }
                this.searchResponse = await searchMetadata({
                    request: {
                        userPrompt,
                        sourceMetadataTypes: this.searchSourceMetadataTypes,
                        usageTypes: this.searchUsageTypes
                    }
                });
            }
        }, () => { this.searchResponse = null; });
    }

    async handleImpact() {
        await this.runOp(async () => {
            this.syncCurrentInputs();
            if (this.isImpactSimple) {
                const queryText = this.impactQueryText ? this.impactQueryText.trim() : '';
                if (!queryText) {
                    throw new Error('Enter a field or object API name.');
                }
                this.impactResponse = await analyzeImpactDirect({
                    queryText,
                    queryType: this.impactQueryType
                });
            } else {
                const userPrompt = this.impactPrompt ? this.impactPrompt.trim() : '';
                if (!userPrompt) {
                    throw new Error('Enter an impact question.');
                }
                this.impactResponse = await analyzeImpact({
                    request: { userPrompt }
                });
            }
            this.selectedGraphNode = this.impactGraph && this.impactGraph.nodes
                ? this.impactGraph.nodes.find((node) => node.depth === 0)
                : null;
        }, () => { this.impactResponse = null; });
    }

    async handleGraphNodeClick(event) {
        const key = event.currentTarget && event.currentTarget.dataset
            ? event.currentTarget.dataset.key
            : '';
        this.selectedGraphNode = this.impactGraph && this.impactGraph.nodes
            ? this.impactGraph.nodes.find((node) => node.key === key)
            : null;
    }

    async handleExpandGraphNode() {
        if (!this.selectedGraphNode) return;
        await this.applyGraphSettings(this.selectedGraphNode.key);
    }

    async handleApplyGraphSettings() {
        if (!this.impactGraph || !this.impactGraph.rootKey) return;
        await this.applyGraphSettings(this.impactGraph.rootKey);
    }

    async applyGraphSettings(rootKey) {
        await this.runOp(async () => {
            this.impactResponse = {
                ...this.impactResponse,
                dependencyGraph: await getDependencyGraph({
                    rootKey,
                    depth: Number(this.impactDepth),
                    direction: this.impactDirection,
                    metadataTypes: this.impactMetadataTypes,
                    hideLowConfidence: this.hideLowConfidence
                })
            };
            this.selectedGraphNode = this.impactResponse.dependencyGraph.nodes.find((node) => node.depth === 0);
        });
    }

    handleOpenGraphNodeInSearch() {
        if (!this.selectedGraphNode) return;
        this.activeTab = 'search';
        this.searchMode = 'simple';
        this.searchQueryText = this.selectedGraphNode.apiName || this.selectedGraphNode.label;
        this.searchQueryType = this.selectedGraphNode.metadataType === 'CustomField'
            ? 'FieldUsage'
            : 'ObjectUsage';
    }

    withCounts(options, counts) {
        const countMap = new Map((counts || []).map((entry) => [entry.value, entry.count]));
        return options.map((option) => ({
            label: countMap.has(option.value) ? `${option.label} (${countMap.get(option.value)})` : option.label,
            value: option.value
        }));
    }

    async handleSecurity() {
        await this.runOp(async () => {
            this.syncCurrentInputs();
            const userPrompt = this.securityPrompt ? this.securityPrompt.trim() : '';
            if (!userPrompt) {
                throw new Error('Enter a security question or field name.');
            }
            this.securityResponse = await runSecurityAuditDirect({ userPrompt });
        }, () => { this.securityResponse = null; });
    }

    async handleDeploymentCompare() {
        await this.runOp(async () => {
            if (!this.selectedBaselineKey || !this.selectedTargetKey) {
                throw new Error('Choose a baseline and a current snapshot before comparing.');
            }
            this.deploymentResponse = await compareEnvironments({
                request: {
                    sourceEnvironment: this.baselineLabel,
                    targetEnvironment: this.currentSnapshotLabel,
                    sourceSnapshotKey: this.selectedBaselineKey,
                    targetSnapshotKey: this.selectedTargetKey
                }
            });
        }, () => { this.deploymentResponse = null; });
    }

    async handleSetBaseline() {
        await this.runOp(async () => {
            const label = this.baselineLabel ? this.baselineLabel.trim() : '';
            if (!label) throw new Error('Enter a baseline label.');
            const response = await captureDeploymentSnapshot({ label });
            if (!response.saved) throw new Error(response.message || 'Baseline snapshot could not be saved.');
            await this.loadDeploymentState();
            this.selectedBaselineKey = response.snapshot.snapshotKey;
            this.selectedTargetKey = '';
            this.deploymentResponse = null;
        });
    }

    async handleCaptureCurrentAndCompare() {
        await this.runOp(async () => {
            if (!this.selectedBaselineKey) throw new Error('Set or choose a baseline first.');
            const label = this.currentSnapshotLabel ? this.currentSnapshotLabel.trim() : '';
            if (!label) throw new Error('Enter a current snapshot label.');
            const response = await captureAndCompareDeployment({
                sourceSnapshotKey: this.selectedBaselineKey,
                currentLabel: label,
                targetEnvironment: 'Current State'
            });
            if (!response.saved) throw new Error(response.message || 'Current snapshot could not be saved.');
            this.deploymentResponse = response.comparison;
            this.selectedTargetKey = response.snapshot.snapshotKey;
            await this.loadDeploymentState();
        }, () => { this.deploymentResponse = null; });
    }

    formatDate(value) {
        if (!value) return 'unknown time';
        return new Intl.DateTimeFormat(undefined, {
            dateStyle: 'short',
            timeStyle: 'short'
        }).format(new Date(value));
    }

    async handleOptimization() {
        await this.runOp(async () => {
            this.optimizationResponse = await runOptimizationScan({ request: { scanType: 'Full' } });
        }, () => { this.optimizationResponse = null; });
    }

    async runOp(operation, onError) {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            await operation();
        } catch (error) {
            if (onError) onError();
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return 'An unexpected error occurred.';
    }
}
