{
  "Comment": "StackAlert multi-account cost monitoring — fan-out per connected account",
  "StartAt": "ListAccounts",
  "States": {
    "ListAccounts": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "FunctionName": "${lambda_arn}",
        "Payload": {
          "mode": "list_accounts"
        }
      },
      "ResultSelector": {
        "accounts.$": "$.Payload.accounts"
      },
      "ResultPath": "$",
      "Retry": [
        {
          "ErrorEquals": ["Lambda.ServiceException", "Lambda.TooManyRequestsException"],
          "IntervalSeconds": 2,
          "MaxAttempts": 2,
          "BackoffRate": 2
        }
      ],
      "Next": "CheckAllAccounts"
    },
    "CheckAllAccounts": {
      "Type": "Map",
      "ItemsPath": "$.accounts",
      "MaxConcurrency": ${max_concurrency},
      "ItemSelector": {
        "mode.$": "$$.Execution.Input.mode",
        "account.$": "$$.Map.Item.Value"
      },
      "ItemProcessor": {
        "ProcessorConfig": {
          "Mode": "INLINE"
        },
        "StartAt": "CheckAccount",
        "States": {
          "CheckAccount": {
            "Type": "Task",
            "Resource": "arn:aws:states:::lambda:invoke",
            "Parameters": {
              "FunctionName": "${lambda_arn}",
              "Payload.$": "$"
            },
            "ResultPath": null,
            "Retry": [
              {
                "ErrorEquals": [
                  "Lambda.ServiceException",
                  "Lambda.AWSLambdaException",
                  "Lambda.SdkClientException",
                  "Lambda.TooManyRequestsException"
                ],
                "IntervalSeconds": 2,
                "MaxAttempts": 3,
                "BackoffRate": 2,
                "JitterStrategy": "FULL"
              }
            ],
            "Catch": [
              {
                "ErrorEquals": ["States.ALL"],
                "Next": "AccountCheckFailed",
                "ResultPath": "$.error"
              }
            ],
            "End": true
          },
          "AccountCheckFailed": {
            "Type": "Pass",
            "Comment": "Log the failure but continue — one bad account should not block others",
            "End": true
          }
        }
      },
      "End": true
    }
  }
}
