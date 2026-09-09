# Data Model

## Core Entities

### Riders
Primary Key: `rider_id`

### Trips
Primary Key: `trip_id`  
Foreign Key: `rider_id`

### Support Tickets
Primary Key: `ticket_id`  
Foreign Keys:
- `trip_id`
- `rider_id`
- `initial_agent_id`

### Support Events
Primary Key: `event_id`  
Foreign Keys:
- `ticket_id`
- `agent_id`

### Financial Adjustments
Primary Key: `adjustment_id`  
Foreign Keys:
- `ticket_id`
- `trip_id`

### Customer Feedback
Primary Key: `feedback_id`  
Foreign Keys:
- `ticket_id`
- `rider_id`

### Experiment Assignments
Primary Key: `assignment_id`  
Foreign Key: `ticket_id`

### Agents
Primary Key: `agent_id`


## Cardinality

| Parent Table | Child Table | Cardinality | Meaning |
| ------------ | ----------- | ----------- | ------- |
| `riders` | `trips` | 1 : many | One rider can take many trips; each trip belongs to one rider. |
| `riders` | `support_tickets` | 1 : many | One rider can create many support tickets; each ticket belongs to one rider. |
| `trips` | `support_tickets` | 1 : 0..many | One trip may have no support ticket, one ticket, or several tickets. |
| `support_tickets` | `support_events` | 1 : many | One ticket can have many events such as assignment, reply, escalation, and resolution. |
| `support_tickets` | `financial_adjustments` | 1 : 0..many | One ticket may have no refund/credit or multiple financial adjustments. |
| `support_tickets` | `customer_feedback` | 1 : 0..1 | One ticket may receive no CSAT response or one response. |
| `support_tickets` | `experiment_assignments` | 1 : 0..1 | A ticket may not particpate in the experiment, eligible tickets receive one assignment. |
| `agents` | `support_events` | 1 : many | One agent can participate in many support events; each event is associated with one agent. |
| `agents` | `support_tickets` | 1 : many | One agent can initially own many tickets; each ticket has at most one initial assigned agent.
| `trips` | `financial_adjustments` | 1 : 0..many | One trip may have no financial adjustment or multiple adjustments. |
