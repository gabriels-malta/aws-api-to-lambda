const { DynamoDBClient, PutItemCommand } = require("@aws-sdk/client-dynamodb");
import { marshall } from "@aws-sdk/util-dynamodb";

const log = (eventCode, message) => {
    const _event = { eventCode }
    if (typeof message === 'object') {
        console.log({ ..._event, ...message });
        return 0;
    }
    _event['message'] = message;
    console.log(_event);
    return 1;
}
export const handler = async (payload, context) => {
    try {
        log('request_received', payload);
        const _item = marshall(payload);
        log('prepare_db_payload', 'Transformed to dynamodb notation.');
        _item["Id"] = { "S": context.awsRequestId };
        const client = new DynamoDBClient();
        const command = new PutItemCommand({
            TableName: "Transactions",
            Item: _item,
            ReturnValues: "NONE",
            ReturnConsumedCapacity: "TOTAL",
            ReturnItemCollectionMetrics: "NONE"
        });
        log('saving_to_db', _item);
        const response = await client.send(command);
        log('request_saved_to_db', response);
        return {
            statusCode: 200,
            body: JSON.stringify({ message: "Item inserido com sucesso", response }),
        };
    } catch (error) {
        console.error("Erro ao inserir item:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Erro ao inserir item", error }),
        };
    }
}