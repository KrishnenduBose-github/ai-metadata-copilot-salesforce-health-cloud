import { LightningElement } from 'lwc';
import refreshMetadataIndex from '@salesforce/apex/MetadataNavigatorController.refreshMetadataIndex';
import searchMetadata from '@salesforce/apex/MetadataNavigatorController.searchMetadata';

export default class MetadataNavigator extends LightningElement {
    queryType = 'FieldUsage';
    queryText = '';
    summary = '';
    impactLevel = '';
    matchCount = 0;
    rows = [];
    errorMessage = '';
    refreshMessage = '';
    isLoading = false;

    columns = [
        { label: 'Source Name', fieldName: 'sourceMetadataName' },
        { label: 'Source Type', fieldName: 'sourceMetadataType' },
        { label: 'Usage Type', fieldName: 'usageType' },
        { label: 'Matched Text', fieldName: 'matchText' },
        { label: 'Target Key', fieldName: 'targetKey' },
        { label: 'Context', fieldName: 'contextSnippet' }
    ];

    queryTypeOptions = [
        { label: 'Field Usage', value: 'FieldUsage' },
        { label: 'Object Usage', value: 'ObjectUsage' }
    ];

    get hasRows() {
        return this.rows.length > 0;
    }

    get hasSummary() {
        return this.summary !== '';
    }

    handleQueryTypeChange(event) {
        this.queryType = event.detail.value;
    }

    handleQueryTextChange(event) {
        this.queryText = event.target.value;
    }

    async handleRefresh() {
        this.isLoading = true;
        this.errorMessage = '';
        this.refreshMessage = '';

        try {
            const result = await refreshMetadataIndex();
            this.refreshMessage =
                'Index refresh completed. Indexed '
                + result.indexedSuccessCount
                + ' item(s) and stored '
                + result.usageSuccessCount
                + ' usage relationship(s).';

            if (result.messages && result.messages.length > 0) {
                this.errorMessage = result.messages.join(' | ');
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSearch() {
        this.isLoading = true;
        this.errorMessage = '';
        this.refreshMessage = '';

        try {
            const result = await searchMetadata({
                queryText: this.queryText,
                queryType: this.queryType
            });

            this.summary = result.summary || '';
            this.impactLevel = result.impactLevel || '';
            this.matchCount = result.matchCount || 0;
            this.rows = result.rows || [];
        } catch (error) {
            this.summary = '';
            this.impactLevel = '';
            this.matchCount = 0;
            this.rows = [];
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }

        if (error && error.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';
    }
}
