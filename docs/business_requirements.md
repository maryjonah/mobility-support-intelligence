## Table of Contents
- [Business Problem](#1-business-problem)
- [Stakeholders](#2-stakeholders)
- [Business Questions](#3-business-questions)
- [Clarifying Questions](#4-clarifying-questions)
- [Decisions the Analysis Should Support](#5-decisions-the-analysis-should-support)
- [Scope](#6-scope)
- [Assumptions](#7-assumptions)


# Business Requirements

## 1. Business Problem

MoveNow does not currently understand what is driving the increase in autonomous-vehicle support costs or whether the new guided support workflow is improving customer outcomes. 

Leadership needs to identify the main operational and financial drivers behind rising support costs so that Customer Support, Product, and Finance can prioritize the most effective improvements.

## 2. Stakeholders

- Customer Support
- Product
- Finance
- Leadership

## 3. Business Questions

| Business Question                                 | Decision                                           | Main KPIs                        |
| :------------------------------------------------ | :------------------------------------------------- | :------------------------------- |
| What drives increasing AV support cost?           | Measures engagement with sponsored                 | Cost/Ticket, Cost/1K Trips, Contact Rate, Resolution Time, Refund/Ticket     |
| Which problems cause repeat contacts/escalations? | Add support capacity or fix the product/workflow?  | Repeat Contact Rate, Escalation Rate, Ticket Volume, Resolution Time  |
| Is guided workflow working?                       | Scale, modify, or discontinue?                     | CSAT, FCR, Repeat Contact Rate, Resolution Time, Escalation Rate, Refund/Ticket  |

## 4. Clarifying Questions 

- Who is the primary decison-maker for this analysis, and what decision do they expect to make from the results?
- How should customer experience be measured for this project? For example, should it be based on CSAT only, or also include repeat contacts, resolution time, and escalation rate?
- Should a repeat contact mean the same customer contacting support about the same trip or issue, and within what time window should it be considered a repeat contact?
- What components should be included in support cost? Should this include agent handling time, refunds or credits, operational downtime, or other costs?
- What reporting period should be used to evaluate  the increase in support costs, and which periods should be compared?
- What qualifies as an AV-related ticket? Should it include only tickets directly linked to an autonomous-vehicle trip, or also support contacts from customers who recently used an AV service?
- How was the guided support workflow rolled out? Is it available to all eligible customers, a selected subset, or a randomly assigned treatment group?
- Has the guided workflow changed since it was introduced, or has the same version been used throughout the analysis period?
- Are there any support issue categories, cities, customer groups, or trip types that leadership already suspects may be contributing to the problem?
- Are there existing metric definitions or Finance/Support reports that this analysis must reconcile with before new KPIs are introduced? 

## 5. Decisions the Analysis Should Support

- Determine which operational or financial drivers should be prioritized to reduce the cost of supporting autonomous-vehicle trips.
- Decide whether high support demand for specific issue categories should be addressed primarily through additional Customer Support capacity or through Product and workflow improvements.
- Determine whether the guided support workflow should be scaled, modified, or discontinued based on its impact on customer experience, operational efficiency, and financial outcomes.
- Identify which cities, support issue categories, trip types, or customer segments require the most immediate intervention.
- Determine whether increasing support costs are primarily caused by growth in trip volume oor by worsening unit-level performance, such as higher contact rates, longer resolution times, or higher refund costs per trip.
- Identify opportunities to reduce avoidable refunds, repeat contacts, escalations, and support handling costs without negatively affecting customer satisfaction.

## 6. Scope

- The analysis focuses primarily on customer-support interactions associated with autonomous-vehicle trips while using rides as a comparison group where relevant.
- The project evaluates customer-support performance, refund activity, operational efficiency, and a guided support workflow.
- The analysis will cover a defined recent reporting period that allows comparison of performance before and after the guided workflow was introduced.
- Support performance will be analysed across dimensions such as city, ride type, issue category, support channel, and escalation status.
- Financial analysis will focus on costs directly attributable to customer-support activity, such as refunds, credits, and estimated agent handling costs.

## 7. Assumptions

- Every trip has a unique `trip_id`.
- Every customer has a unique `rider_id`.
- Support tickets can be linked to a trip whenever the issue relates directly to a ride.
- A repeat contact will be defined using the same rider, trip or issue, and a specified time window.
- Customer satisfaction will primarily be represented using CSAT survey responses.
- The guided support workflow has a treatment and comparison population that allows its performance to be evaluated.
- Refund and support-cost data can be reconciled with corresponding support tickets and trips.
- The exact reporting period, repeat-contact window, and support-cost calculation will be finalized when the dataset and metric definitions are created.