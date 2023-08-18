import { LoggerProvider, StorageJob } from "@mcma/core";
import { ResourceManagerProvider } from "@mcma/client";
import { ProcessJobAssignmentOperation, ProviderCollection, Worker } from "@mcma/worker";
import { SecretsProvider } from "@mcma/secrets";
import { DocumentDatabaseTableProvider } from "@mcma/data";

export function buildWorker(dbTableProvider: DocumentDatabaseTableProvider, loggerProvider: LoggerProvider, resourceManagerProvider: ResourceManagerProvider, secretsProvider: SecretsProvider) {
    const providerCollection = new ProviderCollection({
        dbTableProvider,
        loggerProvider,
        resourceManagerProvider,
        secretsProvider,
    });

    const processJobAssignmentOperation =
        new ProcessJobAssignmentOperation(StorageJob);

    return new Worker(providerCollection)
        .addOperation(processJobAssignmentOperation);
}
