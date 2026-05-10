import { LightningElement } from 'lwc';
import refreshMetadataIndex from '@salesforce/apex/AiMetadataCopilotController.refreshMetadataIndex';
import searchMetadata from '@salesforce/apex/AiMetadataCopilotController.searchMetadata';
import analyzeImpact from '@salesforce/apex/AiMetadataCopilotController.analyzeImpact';
import runSecurityAudit from '@salesforce/apex/AiMetadataCopilotController.runSecurityAudit';
import compareEnvironments from '@salesforce/apex/AiMetadataCopilotController.compareEnvironments';
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
    impactQueryText = '';
    impactQueryType = 'FieldUsage';
    securityPrompt = '';
    safetyFilter = true;
    sourceEnvironment = 'Current Sandbox';
    targetEnvironment = 'Previous Snapshot';

    searchResponse;
    impactResponse;
    securityResponse;
    deploymentResponse;
    optimizationResponse;
    healthStatus;
    refreshResult;

    queryTypeOptions = [
        { label: 'Field Usage', value: 'FieldUsage' },
        { label: 'Object Usage', value: 'ObjectUsage' }
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

    get hasSearchResults() {
        return this.searchResponse && this.searchResponse.matchedComponents && this.searchResponse.matchedComponents.length > 0;
    }

    get hasImpactResults() {
        return this.impactResponse && this.impactResponse.impactedComponents && this.impactResponse.impactedComponents.length > 0;
    }

    get hasSecurityResults() {
        return this.securityResponse && this.securityResponse.findings && this.securityResponse.findings.length > 0;
    }

    get hasDeploymentResults() {
        return this.deploymentResponse && this.deploymentResponse.findings && this.deploymentResponse.findings.length > 0;
    }

    get hasOptimizationResults() {
        return this.optimizationResponse && this.optimizationResponse.findings && this.optimizationResponse.findings.length > 0;
    }

    get healthSummary() {
        if (!this.healthStatus) return 'Loading...';
        const h = this.healthStatus;
        return `Items: ${h.indexedItemCount || 0} | Relationships: ${h.usageRecordCount || 0} | Snapshots: ${h.snapshotCount || 0}`;
    }

    get isSearchSimple() { return this.searchMode === 'simple'; }
    get isImpactSimple() { return this.impactMode === 'simple'; }
    get searchModeLabel() { return this.isSearchSimple ? 'Direct API Name' : 'Natural Language'; }
    get impactModeLabel() { return this.isImpactSimple ? 'Direct API Name' : 'Natural Language'; }

    connectedCallback() {
        this.loadHealthStatus();
    }

    handleTabChange(event) { this.activeTab = event.target.value; }
    handleSearchModeChange(event) { this.searchMode = event.target.value; }
    handleImpactModeChange(event) { this.impactMode = event.target.value; }

    handleSearchPromptChange(event) { this.searchPrompt = this.readInput(event); }
    handleImpactPromptChange(event) { this.impactPrompt = this.readInput(event); }
    handleSearchQueryTextChange(event) { this.searchQueryText = this.readInput(event); }
    handleSearchQueryTypeChange(event) { this.searchQueryType = this.readInput(event); }
    handleImpactQueryTextChange(event) { this.impactQueryText = this.readInput(event); }
    handleImpactQueryTypeChange(event) { this.impactQueryType = this.readInput(event); }
    handleSecurityPromptChange(event) { this.securityPrompt = this.readInput(event); }
    handleSourceEnvChange(event) { this.sourceEnvironment = this.readInput(event); }
    handleTargetEnvChange(event) { this.targetEnvironment = this.readInput(event); }

    readInput(event) {
        if (event && event.detail && event.detail.value !== undefined) return event.detail.value;
        return event && event.target ? event.target.value : '';
    }

    async loadHealthStatus() {
        try {
            this.healthStatus = await checkHealth();
        } catch (error) {
            this.healthStatus = { isHealthy: false, indexedItemCount: 0, usageRecordCount: 0, warnings: [this.reduceError(error)], recommendations: [] };
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
            if (this.isSearchSimple) {
                if (!this.searchQueryText || !this.searchQueryText.trim()) {
                    throw new Error('Enter a field or object API name.');
                }
                this.searchResponse = await searchMetadata({
                    request: {
                        queryText: this.searchQueryText,
                        queryType: this.searchQueryType
                    }
                });
            } else {
                if (!this.searchPrompt || !this.searchPrompt.trim()) {
                    throw new Error('Enter a metadata question.');
                }
                this.searchResponse = await searchMetadata({
                    request: { userPrompt: this.searchPrompt }
                });
            }
        }, () => { this.searchResponse = null; });
    }

    async handleImpact() {
        await this.runOp(async () => {
            if (this.isImpactSimple) {
                if (!this.impactQueryText || !this.impactQueryText.trim()) {
                    throw new Error('Enter a field or object API name.');
                }
                this.impactResponse = await analyzeImpact({
                    request: {
                        queryText: this.impactQueryText,
                        queryType: this.impactQueryType
                    }
                });
            } else {
                if (!this.impactPrompt || !this.impactPrompt.trim()) {
                    throw new Error('Enter an impact question.');
                }
                this.impactResponse = await analyzeImpact({
                    request: { userPrompt: this.impactPrompt }
                });
            }
        }, () => { this.impactResponse = null; });
    }

    async handleSecurity() {
        await this.runOp(async () => {
            if (!this.securityPrompt || !this.securityPrompt.trim()) {
                throw new Error('Enter a security question or field name.');
            }
            this.securityResponse = await runSecurityAudit({
                request: {
                    userPrompt: this.securityPrompt
                }
            });
        }, () => { this.securityResponse = null; });
    }

    async handleDeploymentCompare() {
        await this.runOp(async () => {
            if (!this.sourceEnvironment || !this.sourceEnvironment.trim()) throw new Error('Enter a source environment.');
            if (!this.targetEnvironment || !this.targetEnvironment.trim()) throw new Error('Enter a target environment.');
            this.deploymentResponse = await compareEnvironments({
                request: {
                    sourceEnvironment: this.sourceEnvironment,
                    targetEnvironment: this.targetEnvironment
                }
            });
        }, () => { this.deploymentResponse = null; });
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

    severityClass(response) {
        if (!response) return '';
        const s = response.severity || '';
        if (s === 'Critical' || s === 'High') return 'badge-red';
        if (s === 'Medium') return 'badge-amber';
        return 'badge-green';
    }
}
