# AWS Budget Setup and Operations

This guide creates a conservative monthly cost guardrail for the LifeOS AWS
Archive. It is intended to detect unexpected account charges while the archive
grows and objects transition between S3 storage classes.

AWS Budgets is an alerting service, not a real-time spending cap. AWS typically
updates budget information up to three times per day, with updates commonly
occurring 8–12 hours apart. Charges can continue accumulating before an alert
arrives.

## Recommended Initial Configuration

| Setting | Value |
| --- | --- |
| Budget name | `lifeos-monthly-cost` |
| Budget type | Cost budget |
| Period | Monthly |
| Renewal | Recurring |
| Budgeting method | Fixed |
| Amount | `$10.00 USD` |
| Scope | Entire AWS account |
| Cost aggregation | Unblended cost |
| Notifications | Email |
| Automated actions | None initially |

The `$10` amount is an initial guardrail, not a prediction of the final monthly
bill. Review it after one complete billing month and after significant archive
growth or restore activity.

## Alert Plan

Configure all four notifications with the same monitored email address.

| Threshold | Basis | Approximate amount | Purpose |
| ---: | --- | ---: | --- |
| 50% | Actual | `$5.00` | Early indication that normal spending is accumulating |
| 80% | Forecasted | `$8.00` | Warning that AWS predicts the budget will be approached |
| 80% | Actual | `$8.00` | Confirmation that most of the monthly budget is consumed |
| 100% | Actual | `$10.00` | Budget threshold exceeded |

Percentage thresholds remain aligned automatically if the monthly budget
amount is changed later.

## Prerequisites

Before starting:

1. Sign in to the AWS account that owns the LifeOS archive.
2. Confirm that the identity has permission to view billing information and
   create budgets.
3. Have the notification email address available.
4. Review the current month-to-date cost on the Billing dashboard. If it already
   exceeds `$10`, choose a temporary amount above the current total and revisit
   the limit after a complete billing month.

## Create the Monthly Cost Budget

### 1. Open AWS Budgets

1. Open the [AWS Billing and Cost Management console][billing-console].
2. In the navigation pane, select **Budgets**.
3. Select **Create budget**.

### 2. Select the budget type

1. Under **Budget setup**, choose **Customize (advanced)**.
2. Under **Budget types**, choose **Cost budget**.
3. Select **Next**.

The advanced workflow exposes the fixed amount, cost scope, and individual
actual and forecasted notification settings needed for this project.

### 3. Configure budget details

Enter the following values:

1. **Budget name:** `lifeos-monthly-cost`
2. **Period:** Monthly
3. **Budget renewal type:** Recurring budget
4. **Start month:** Current month
5. **Budgeting method:** Fixed
6. **Budgeted amount:** `10.00`

Do not select an expiring budget. The archive incurs ongoing storage charges
and needs continuous monitoring.

### 4. Configure the budget scope

Use an account-wide budget initially:

1. Leave service, region, tag, and usage-type filters empty.
2. Select **Unblended cost** if the console requests a cost aggregation method.
3. Review advanced cost options without excluding ordinary account charges.

An account-wide scope catches accidental charges from services other than S3.
A service-specific S3 budget can be added later, but it should supplement—not
replace—the account guardrail.

Select **Next**.

### 5. Add the 50% actual alert

1. Select **Add an alert threshold**.
2. Enter `50` for the threshold.
3. Choose **% of budgeted amount**.
4. Choose **Actual**.
5. Enter the notification email address.

### 6. Add the 80% forecasted alert

1. Add another alert threshold.
2. Enter `80`.
3. Choose **% of budgeted amount**.
4. Choose **Forecasted**.
5. Enter the same notification email address.

Forecast alerts can provide notice before the actual threshold is crossed, but
they depend on AWS having enough billing history to calculate a forecast.

### 7. Add the 80% actual alert

1. Add another alert threshold.
2. Enter `80`.
3. Choose **% of budgeted amount**.
4. Choose **Actual**.
5. Enter the same notification email address.

### 8. Add the 100% actual alert

1. Add the final alert threshold.
2. Enter `100`.
3. Choose **% of budgeted amount**.
4. Choose **Actual**.
5. Enter the same notification email address.

### 9. Skip automated budget actions

Do not attach an automated action during the initial implementation.

Budget actions can apply IAM or service-control policies and can affect running
resources. Automatic restrictions are inappropriate until their impact on
archive uploads, logging, restores, and CloudFormation operations has been
tested separately.

Select **Next**.

### 10. Review and create

Before creating the budget, confirm:

- The name is `lifeos-monthly-cost`.
- The period is monthly and recurring.
- The amount is `$10.00`.
- The budget covers the entire account.
- Four email notifications are configured.
- Actual and forecasted alerts use the correct bases.
- No automated actions are attached.

Select **Create budget**.

## Validate the Configuration

After creation:

1. Confirm that `lifeos-monthly-cost` appears in the Budgets list.
2. Open the budget and verify its period, amount, scope, and thresholds.
3. Confirm that all four notifications show the intended email recipient.
4. Record the creation date and budget amount in the Trello cost-alert card.
5. Recheck the budget on the following day after AWS processes additional
   billing data.

Direct budget email recipients do not use the Amazon SNS subscription workflow.
If an SNS topic is added later, each SNS email subscription must be confirmed
from the AWS confirmation message before it can receive alerts.

## Respond to an Alert

An alert is a prompt to investigate, not proof that S3 storage caused the
increase.

1. Open **Billing and Cost Management**.
2. Review month-to-date and forecasted spend.
3. Open **Cost Explorer**.
4. Group costs by **Service**.
5. If S3 is responsible, group or filter further by region and usage type.
6. Check recent uploads, restores, request volume, logging growth, and storage
   class transitions.
7. Look for unfamiliar services or regions.
8. Record the cause and resolution on the Trello card or monthly review.
9. Change the budget only when the higher cost is understood and intentional.

Do not delete S3 objects, disable logging, or change lifecycle rules solely to
silence an alert. Confirm the cost driver and archive-safety impact first.

## Monthly Review

Complete this review once each month:

1. Record the final cost for the previous month.
2. Compare actual cost with the `$10` budget.
3. Review costs by AWS service and S3 usage type.
4. Check whether recent uploads or restores explain material changes.
5. Confirm expected lifecycle transitions are occurring.
6. Review noncurrent-version storage for unexpected growth.
7. Confirm the notification email remains current.
8. Adjust the budget only if the expected baseline has changed.
9. Record the result in **Monthly archive and cost review** on Trello.

After two or three stable months, consider adding:

- An S3-specific cost budget
- AWS Cost Anomaly Detection
- A monthly budget report
- SNS or chat notifications

Each addition should have a clear operational purpose; more alerts are not
automatically better.

## Troubleshooting

### The budget graph is empty

Cost Explorer may not have been enabled previously. AWS can enable it when the
first budget is created, and the graph can take up to 24 hours to appear.

### No forecast is available

Forecasts require sufficient billing data. Keep the actual-spend alerts active
and check again after AWS has accumulated more account history.

### An alert arrived after the threshold was exceeded

This is expected behavior. Budget data is delayed, and additional charges can
accrue before a notification is delivered. AWS Budgets is not a real-time hard
limit.

### SNS notifications are not arriving

Open the email sent by Amazon SNS and confirm the subscription. Direct budget
email recipients and SNS subscriptions are configured differently.

### The budget is noisy

Investigate whether the budget is too low, credits are masking or changing the
baseline, or one-time restore activity caused the increase. Preserve the early
warning thresholds unless repeated alerts are understood and harmless.

## Trello Completion Checklist

- [ ] Create the `$10` monthly account cost budget
- [ ] Add the 50% actual alert
- [ ] Add the 80% forecasted alert
- [ ] Add the 80% actual alert
- [ ] Add the 100% actual alert
- [ ] Verify the notification email on all alerts
- [ ] Confirm no automated budget actions are attached
- [ ] Confirm the budget appears in AWS Budgets
- [ ] Recheck budget data the following day
- [ ] Review the amount after one complete billing month

## Official AWS References

- [Creating a cost budget][create-cost-budget]
- [Managing costs with AWS Budgets][manage-budgets]
- [AWS Budgets pricing][budgets-pricing]
- [AWS Budget methods][budget-methods]

[billing-console]: https://console.aws.amazon.com/cost-management/
[create-cost-budget]: https://docs.aws.amazon.com/cost-management/latest/userguide/create-cost-budget.html
[manage-budgets]: https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html
[budgets-pricing]: https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/
[budget-methods]: https://docs.aws.amazon.com/cost-management/latest/userguide/budget-methods.html
