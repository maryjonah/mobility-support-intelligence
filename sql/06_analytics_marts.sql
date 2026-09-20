CREATE SCHEMA IF NOT EXISTS analytics;

-- 1. Mart 1: Ticket Performance
-- Each row contains details per support ticket containing the operational, financial, customer, and trip context.

CREATE OR REPLACE VIEW analytics.mart_ticket_performance AS
WITH event_summary AS (
	SELECT
		st.ticket_id,
		SUM(COALESCE(se.handling_minutes, 0)) AS total_handling_minutes,
		MAX(CASE WHEN se.escalation_flag = TRUE THEN 1 ELSE 0 END) AS was_escalated
	FROM support_tickets as st
	LEFT JOIN support_events as se
	ON st.ticket_id = se.ticket_id
	GROUP BY st.ticket_id
),
repeat_summary AS (
	SELECT
		parent.ticket_id,
		MAX(CASE WHEN child.ticket_id IS NOT NULL THEN 1 ELSE 0 END) AS had_repeat_contact
	FROM support_tickets as parent
	LEFT JOIN support_tickets as child
		ON child.parent_ticket_id = parent.ticket_id
		AND child.rider_id = parent.rider_id
		AND child.issue_type = parent.issue_type
		AND child.opened_at >= parent.resolved_at
		AND child.opened_at <= parent.resolved_at + INTERVAL '7 days'
	GROUP BY parent.ticket_id
),
labor_summary AS (
	SELECT
		se.ticket_id,
		SUM(se.handling_minutes / 60.0 * a.cost_per_hout) AS agent_labor_cost
	FROM support_events as se
	JOIN agents as a
		ON se.agent_id = a.agent_id
	JOIN support_tickets as st
		ON se.ticket_id = st.ticket_id
	GROUP BY se.ticket_id
),
deduplicated_adjustments AS (
	SELECT DISTINCT ON (adjustment_id)
		adjustment_id,
		ticket_id,
		adjustment_type,
		amount
	FROM financial_adjustments
	ORDER BY adjustment_id
),
	adjustment_summary AS (
	SELECT
		ticket_id,
		SUM(CASE WHEN adjustment_type = 'refund' THEN amount ELSE 0 END) AS refund_cost,
		SUM(CASE WHEN adjustment_type = 'appeasement_credit' THEN amount ELSE 0 END) AS appeasement_cost
	FROM deduplicated_adjustments
	GROUP BY ticket_id
)
SELECT 
	st.ticket_id,
	st.trip_id,
	st.rider_id,
	st.parent_ticket_id,
	st.issue_type,
	st.channel,
	st.status,
	st.initial_agent_id,
	st.opened_at,
	st.resolved_at,
	t.city,
	t.ride_type,
	t.trip_status,
	t.fare_amount,
	t.distance_km,
	CASE WHEN st.parent_ticket_id IS NULL THEN 0 ELSE 1 END AS is_repeat_ticket,
	COALESCE(rs.had_repeat_contact, 0) AS had_repeat_contact,
	COALESCE(es.was_escalated, 0) AS was_escalated,
	CASE
        WHEN st.resolved_at >= st.opened_at
        THEN EXTRACT(EPOCH FROM (st.resolved_at - st.opened_at)) / 60
        ELSE NULL
    END AS resolution_minutes,
	COALESCE(es.total_handling_minutes, 0) AS total_handling_minutes,
	ROUND(COALESCE(ls.agent_labor_cost, 0), 2) AS agent_labor_cost,
	ROUND(COALESCE(adj.refund_cost, 0), 2) AS refund_cost,
	ROUND(COALESCE(adj.appeasement_cost), 2) AS appeasement_cost,
	ROUND(
		COALESCE(ls.agent_labor_cost, 0) + COALESCE(adj.refund_cost, 0) + COALESCE(adj.appeasement_cost, 0)
	, 2) AS total_support_cost,
	CASE WHEN cf.csat_score BETWEEN 1 AND 5 THEN cf.csat_score ELSE NULL END AS csat_score,
	CASE WHEN cf.csat_score IN (4, 5) THEN 1 WHEN cf.csat_score BETWEEN 1 AND 3 THEN 0 ELSE NULL END AS csat_satisfied,
	CASE WHEN st.trip_id IS NULL THEN 1 ELSE 0 END AS missing_trip_flag,
	CASE WHEN st.resolved_at < st.opened_at THEN 1 ELSE 0 END AS invalid_resolution_time_flag
FROM support_tickets AS st
LEFT JOIN trips as t
	ON st.trip_id = t.trip_id
LEFT JOIN event_summary as es
	ON st.ticket_id = es.ticket_id
LEFT JOIN repeat_summary as rs
	ON st.ticket_id = rs.ticket_id
LEFT JOIN labor_summary as ls
	ON st.ticket_id = ls.ticket_id
LEFT JOIN adjustment_summary as adj
	ON st.ticket_id = adj.ticket_id
LEFT JOIN customer_feedback as cf
	ON st.ticket_id = cf.ticket_id;


-- 2. Mart 2: Support Performance
-- Each row contains trip information with aggregated support activity

CREATE OR REPLACE VIEW analytics.mart_trip_support_performance AS
WITH ticket_summary AS (
	SELECT
		trip_id,
		COUNT(ticket_id) AS support_ticket_count,
		COUNT(CASE WHEN parent_ticket_id IS NULL THEN ticket_id END) AS primary_ticket_count,
		SUM(is_repeat_ticket) AS repeat_ticket_count,
		MAX(had_repeat_contact) AS had_repeat_contact,
		SUM(was_escalated) AS escalated_ticket_count,
		MAX(was_escalated) AS had_escalation,
		SUM(total_handling_minutes) AS total_handling_minutes,
		AVG(resolution_minutes) AS avg_resolution_minutes,
		SUM(agent_labor_cost) AS agent_labor_cost,
		SUM(refund_cost) AS refund_cost,
		SUM(appeasement_cost) AS appeasement_cost,
		SUM(total_support_cost) AS total_support_cost,
		COUNT(csat_score) AS survey_response_count,
		SUM(csat_satisfied) AS satisfied_response_count,
		AVG(csat_score) AS avg_csat_score
	FROM analytics.mart_ticket_performance
	WHERE trip_id IS NOT NULL
	GROUP BY trip_id
)
SELECT
	t.trip_id,
	t.rider_id,
	t.city,
	t.ride_type,
	t.requested_at,
	t.started_at,
	t.completed_at,
	t.cancelled_at,
	t.trip_status,
	t.fare_amount,
	t.distance_km,
	CASE WHEN ts.support_ticket_count > 0 THEN 1 ELSE 0 END AS had_support_contact,
	COALESCE(ts.support_ticket_count, 0) AS support_ticket_count,
	COALESCE(ts.primary_ticket_count, 0) AS primary_ticket_count,
	COALESCE(ts.repeat_ticket_count, 0) AS repeat_ticket_count,
	COALESCE(ts.had_repeat_contact, 0) AS had_repeat_contact,
	COALESCE(ts.escalated_ticket_count, 0) AS escalated_ticket_count,
	COALESCE(ts.had_escalation, 0) AS had_escalation,
	COALESCE(ts.total_handling_minutes, 0) AS total_handling_minutes,
	ts.avg_resolution_minutes,
	ROUND(COALESCE(ts.agent_labor_cost, 0), 2) AS agent_labor_cost,
	ROUND(COALESCE(ts.refund_cost, 0), 2) AS refund_cost,
	ROUND(COALESCE(ts.appeasement_cost, 0), 2) AS appeasement_cost,
	ROUND(COALESCE(ts.total_support_cost, 0), 2) AS total_support_cost,
	COALESCE(ts.survey_response_count, 0) AS survey_response_count,
	COALESCE(ts.satisfied_response_count, 0) AS satisfied_response_count,
	ROUND(ts.avg_csat_score) AS avg_csat_score
	FROM trips as t
LEFT JOIN ticket_summary as ts
	ON t.trip_id = ts.trip_id;
