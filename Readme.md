# Food Delivery Product Analytics

An end-to-end product analytics portfolio project investigating conversion funnels, customer retention, and the impact of an estimated delivery time (ETA) feature on checkout behaviour.

**Tools:** PostgreSQL · Python · Power BI

## Business Problem

A simulated food-delivery app introduced an ETA display on the cart review screen. The objective was to evaluate whether the feature improved checkout conversion without negatively affecting cancellations or operational performance.

## Analysis

- **Funnel analysis (SQL):** Measured user progression through key journey stages and identified conversion drop-offs.
- **Cohort retention (SQL):** Analysed weekly retention patterns and repeat ordering across acquisition channels.
- **A/B testing (Python):** Compared control and treatment checkout conversion using user-level experiment data, confidence intervals, and hypothesis testing.
- **Dashboard (Power BI):** Built interactive pages for funnel performance, cohort retention, and experiment outcomes.
- **Guardrail analysis:** Evaluated cancellation rates, average order value, and delivery time.

## Key Results

- End-to-end funnel conversion: **22.6%**.
- Control checkout conversion: **62.07%**.
- Treatment checkout conversion: **64.68%**.
- Absolute conversion lift: **+2.61 percentage points** (95% CI: +1.71 to +3.51).
- Cancellation rate increased from **4.77% to 5.19%**, a difference of +0.42 percentage points.

The conversion difference was statistically significant (p = 1.2 × 10⁻⁸). The cancellation increase was also statistically significant (p = 0.0077).

## Recommendation

The simulated experiment showed higher checkout conversion alongside a significant increase in cancellations. The analysis supports investigating the cancellation increase and monitoring operational guardrails before expanding the feature rollout.

## Dashboard

The Power BI report contains three pages:

1. **Funnel:** Sessions by event stage and end-to-end conversion.
2. **Retention:** Weekly cohort retention heatmap and repeat rate by channel.
3. **Experiment:** Control versus treatment conversion and guardrail metrics.

Dashboard screenshots are available in the `screenshots/` directory.

## Project Structure

- `sql/` — Funnel, retention, and experiment SQL queries.
- `python/` — Synthetic data generation and statistical analysis.
- `powerbi/` — Power BI report.
- `screenshots/` — Dashboard screenshots.

Update these paths to match the actual repository structure.

## Data and Limitations

This project uses **synthetic data** generated for analytical practice. The treatment effect was deliberately introduced during data generation. The results demonstrate the analysis workflow and statistical methods; they are not evidence about a real company or real customers.

The project does not establish how the feature would perform on production data. Further investigation would be needed to understand the cancellation increase and validate operational impacts.

## Reproducibility

See the scripts and their comments for the data-generation, SQL analysis, and statistical testing workflow. Configure database connection details locally; do not commit passwords or credentials.
