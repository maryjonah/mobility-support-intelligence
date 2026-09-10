## Table of Contents
- [Required Data Sources](#2-required-data-sources)
    - [Trips](#21-trips-data)
    - [Support Tickets](#22-support-tickets)
    - [Support Events](#23-support-events)
    - [Financial Adjustments](#24-financial-adjustments)
    - [Customer Feedback](#25-customer-feedback)
    - [Experiment Assignments](#26-experiment-assignments)
    - [Agents](#27-agents)
- [KPI-to-Data Mapping](#3-kpi-to-data-mapping)
- [Synthetic Data Generation Rules](#4-synthetic-data-generation-rules)

# Data Requirements

## 1. Overview

The document defines the datasets and fields required to support the Mobility Support Intelligence analysis and its associated KPIs.


## 2. Required Data Sources

### 2.1. Trips Data

| Field | Description | Why We Need It |
| ----- | ----------- | -------------- |
| `trip_id` | Unique identifier for each trip | Links trips to support tickets, refunds and other events |
| `rider_id` | Unique identifier for the customer | Helps track customer-level support interactions |
| `city` | City where the trip occurred | Allows performance comparison across markets |
| `ride_type` | AV or traditional ride | Allows comparison between autonomous and traditional trips |
| `requested_at` | Date/time the trip was requested | Supports time-based analysis |
| `completed_at` | Date/time the trip successfully ended | Supports trip duration and reporting-period analysis |
| `trip_status` | Completed, cancelled, failed, etc. | Determines which trips should be included in metrics |
| `fare_amount` | Amount charged for the trip | Supports financial analysis and refund comparisons |
| `distance_km` | Distance travelled | Allows investigation of whether trip characteristics affect support outcomes |
| `started_at` | Date/time the trip actually began | Helps distinguish trips that started successfully from trips cancelled before pickup |
| `cancelled_at` | Date/time the trip was cancelled | Helps distinguish pre-start from in-trip cancellations and assess whether cancellation behavior contributes to support contacts, refunds, or other customer issues |

### 2.2. Support Tickets

| Field | Description | Why We Need It |
| ----- | ----------- | -------------- |
| `ticket_id` | Unique identifier for each support case | Primary identifier for support analysis |
| `trip_id` | Trip associated with the ticket | Connects the support issue to the ride |
| `rider_id` | Customer who opened the ticket | Helps identify repeat contacts |
| `opened_at` | Time the ticket was opened | Used to calculate resolution time |
| `resolved_at` | Time the ticket was resolved | Used to calculate resolution time |
| `issue_type` | Category of customer problem | Enables root-cause analysis |
| `channel` | Chat, phone, app, email, etc. | Allows analysis of support-channel performance |
| `priority` | Severity/priority of the case | Helps distinguish simple and complex issue |
| `status` | Open, resolved, closed, etc. | Determines eligible support cases |
| `initial_agent_id` | First agent assigned to the ticket | Connects cases to support operations |
| `workflow_type` | Standard or guided workflow | Helps evaluate the new support workflow |

### 2.3. Support Events

| Field | Description | Why We Need It |
| ----- | ----------- | -------------- |
| `event_id` | Unique support-event identifier | Identifies each event |
| `ticket_id` | Ticket associated with the event | Links event history to support cases |
| `event_time` | Time the event occurred | Reconstructs the support timeline |
| `event_type` | Assignment, escalation, reply, resolution, etc. | Shows what occurred during the case |
| `agent_id` | Agent associated with the event | Supports workload and cost calculations |
| `escalation_flag` | Whether the event represented an escalation | Used to calculate Escalation Rate |
| `handling_minutes` | Active agent handling time | Allows estimation of support labour cost |

### 2.4. Financial Adjustments

| Field | Description | Why We Need It |
| ----- | ----------- | -------------- |
| `adjustment_id` | Unique identifier for each financial adjustment | Identifies individual refund/credit transaction |
| `ticket_id` | Support ticket associated with the adjustment | Connects financial impact to support problems |
| `trip_id` | Trip associated with the adjustment | Allows financial analysis by ride type and trip |
| `adjustment_type` | Refund, credit, appeasement, etc. | Allows different financial adjustments to be analysed separately |
| `amount` | Monetary value of the adjustment | Used to calculate refund and support costs |
| `reason` | Reason for issuing the adjustment | Helps identify financial drivers |
| `created_at` | Date/time adjustment was issued | Supports reporting-period analysis |
| `currency` | Currency of the adjustment | Prevents incorrectly combining different currencies |

### 2.5. Customer Feedback
NB: Not every ticket will have a CSAT response

| Field | Description | Why We Need It |
| ----- | ----------- | -------------- |
| `feedback_id` | Unique feedback-response identifier | Identifies each survey response |
| `ticket_id` | Support ticket associated with the survey | Connects satisfaction to the support experience |
| `rider_id` | Customer submitting feedback | Supports customer-level validation |
| `csat_score` | Customer satisfaction rating, e.g. 1-5 | Used to calculate CSAT |
| `submitted_at` | Date/time feedback was submitted | Supports time-based analysis |
| `feedback_category` | Optional category for feedback | Helps investigate reasons behind satisfaction/dissatisfaction |

### 2.6. Experiment Assignments
_NB:_  
Control = Standard Support Workflow  
Treatment = Guided Support Workflow

| Field | Description | Why We Need It |
| ----- | ----------- | -------------- |
| `assignment_id` | Unique experiment assignment | Identifies each experiment record |
| `ticket_id` | Ticket participating in the experiment | Connects experiment assignment to support outcomes |
| `experiment_name` | Name/version of the experiment | Allows multiple experiments or versions |
| `experiment_group` | Control or Treatment | Enables comparison between workflows |
| `assigned_at` | Time the ticket entered the experiment | Validates timing |
| `eligibility_flag` | Whether case met experiment criteria | Helps define the valid experiment population |


### 2.7. Agents 

| Field | Description | Why We Need It |
| ----- | ----------- | -------------- |
| `agent_id` | Unique support-agent identifier | Links agents to support events |
| `support_team` | Team or specialization | Enables team-level analysis |
| `tenure_months` | Length of agent experience | Allow analysis of whether experience affects outcomes |
| `cost_per_hour` | Estimated hourly labour cost | Used to estimate support handling cost |
| `location` | Agent/ team location | Allows operational comparisons |
| `active_flag` | Whether agent is currently active | Supports accurate workforce analysis |


## 3. KPI-to-Data Mapping

| Field | Primary Data | Supporting Data | Key Fields |
| ----- | ------------ | --------------- | ---------- |
| Repeat Contact Rate | Support Tickets | Support Events | `ticket_id, rider_id, trip_id, opened_at, event_time, event_type` | 
| Support Cost per 1,000 Trips | Trips, Support Events | Agents, Financial Adjustments | `trip_id, handling_minutes, agent_id, cost_per_hour, amount` |
| First Contact Resolution Rate | Support Tickets | Support Events | `ticket_id, status, resolved_at, event_type, escalation_flag` |
| Contact Rate per 1,000 Trips | Trips, Support Tickets | - | `trip_id, ticket_id, ride_type, trip_status` |
| Escalation Rate | Support Events | Support Tickets | `ticket_id, event_type, escalation_flag` |
| Average Resolution Time | Support Tickets | Support Events | `ticket_id, opened_at, resolved_at, status` |
| Customer Satisfaction Score (CSAT) | Customer Feedback | Support Tickets | `feedback_id, ticket_id, csat_score` |
| Refund Cost per Ticket | Financial Adjustments | Support Tickets | `ticket_id, adjustment_type, amount` |


## 4. Synthetic Data Generation Rules

- Analysis period: January 1, 2026 to June 30, 2026
- Approximately 120,000 trips
- Approximately 25,000 riders
- Ride types: AV and Traditional
- Approximately 35% of trips are AV trips
- Support tickets are generated from a subset of trips
- Support outcomes depend partly on issue complexity
- The guided support workflow launches on April 1, 2026
- Eligible post-launch AV tickets may be assigned to Control or Treatment
- CSAT is influenced by support outcomes rather than generated independently
- Refund probability and amount vary by issue type and support experience
- Agent labour cost is estimated from handling time and hourly agent cost
- A small number of deliberate data-quality issues will be introduced