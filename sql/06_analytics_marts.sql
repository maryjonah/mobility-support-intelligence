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
