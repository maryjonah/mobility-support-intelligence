-- Not including constraint since we have some duplicate data and it will not be possible to import in created table


-- 1. Riders
CREATE TABLE IF NOT EXISTS riders (
	rider_id 			VARCHAR(20),
	signup_date 		DATE,
	home_city 			VARCHAR(50),
	customer_segment 	VARCHAR(50)
);


-- 2. Agents
CREATE TABLE IF NOT EXISTS agents (
	agent_id 			VARCHAR(20),
	supporrt_team 		VARCHAR(50),
	tenure_months 		INTEGER,
	cost_per_hout 		NUMERIC(10, 2),
	location 			VARCHAR(50),
	active_flag 		BOOLEAN
);


-- 3. Trips
CREATE TABLE IF NOT EXISTS trips (
	trip_id 			VARCHAR(20),
	rider_id 			VARCHAR(20),
	city 				VARCHAR(50),
	ride_type			VARCHAR(30),
	requested_at 		TIMESTAMP,
	started_at 			TIMESTAMP,
	completed_at		TIMESTAMP,
	cancelled_at 		TIMESTAMP,
	trip_status 		VARCHAR(30),
	fare_amount 		NUMERIC(10, 2),
	distance_km 		NUMERIC(10, 2)
);


-- 4. Support Tickets
CREATE TABLE IF NOT EXISTS support_tickets (
	ticket_id 			VARCHAR(30),
	trip_id 			VARCHAR(20),
	rider_id 			VARCHAR(20),
	parent_ticket_id 	VARCHAR(30),
	opened_at 			TIMESTAMP,
	resolved_at			TIMESTAMP,
	issue_type 			VARCHAR(50),
	channel 			VARCHAR(30),
	priority 			VARCHAR(30),
	status 				VARCHAR(30),
	initial_agent_id 	VARCHAR(20)
);


-- 5. Support Events
CREATE TABLE IF NOT EXISTS support_events (
	event_id 			VARCHAR(30),
	ticket_id 			VARCHAR(30),
	event_time 			TIMESTAMP,
	event_type 			VARCHAR(50),
	agent_id 			VARCHAR(20),
	escalation_flag 	BOOLEAN,
	handling_minutes 	NUMERIC(10, 2)
);


-- 6. Financial Adjustments
CREATE TABLE IF NOT EXISTS financial_adjustments (
	adjustment_id 		VARCHAR(30),
	ticket_id 			VARCHAR(30),
	trip_id 			VARCHAR(20),
	adjustment_type 	VARCHAR(50),
	amount 				NUMERIC(10, 2),
	reason 				VARCHAR(100),
	created_at 			TIMESTAMP,
	currency 			VARCHAR(10)
);


-- 7. Customer Feedback
CREATE TABLE IF NOT EXISTS customer_feedback (
	feedback_id 		VARCHAR(30),
	ticket_id 			VARCHAR(30),
	rider_id 			VARCHAR(20),
	csat_score 			INTEGER,
	submitted_at 		TIMESTAMP,
	feedback_category 	VARCHAR(30)
);


-- 8. Experiment Assignments
CREATE TABLE IF NOT EXISTS experiment_assignments (
	assignment_id 		VARCHAR(30),
	ticket_id 			VARCHAR(30),
	experiment_name 	VARCHAR(100),
	experiment_group 	VARCHAR(30),
	assigned_at 		TIMESTAMP,
	eligibility_flag 	BOOLEAN
);


-- Return the number of rows in the tables after Import
SELECT 'riders' AS table_name, COUNT(*) AS row_count
FROM riders

UNION ALL

SELECT 'agents', COUNT(*)
FROM agents

UNION ALL

SELECT 'trips', COUNT(*)
FROM trips

UNION ALL

SELECT 'support_tickets', COUNT(*)
FROM support_tickets

UNION ALL

SELECT 'support_events', COUNT(*)
FROM support_events

UNION

SELECT 'financial_adjustments', COUNT(*)
FROM financial_adjustments

UNION ALL

SELECT 'customer_feedback', COUNT(*)
FROM customer_feedback

UNION ALL

SELECT 'experiment_assignments', COUNT(*)
FROM experiment_assignments;