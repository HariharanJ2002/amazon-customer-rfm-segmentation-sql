# Data Dictionary

This project uses a 500-user sample drawn from a larger Amazon purchase/survey
dataset (~1.85M rows, 5,000 unique users). The table below documents the
schema used in the SQL analysis. **Raw data is not included in this repository**
due to the presence of respondent-level demographic fields; the row below is
a fabricated example for illustration only.

## Table: `amazon_survey`

| Column                     | Type    | Description                                                        |
|----------------------------|---------|---------------------------------------------------------------------|
| `user_id`                  | text    | Anonymized unique identifier for each survey respondent/customer   |
| `product_id`               | text    | Amazon product identifier (ASIN)                                  |
| `category`                 | text    | Product category (e.g., Electronics, Beauty). "Unknown" where category was not captured in the source data |
| `title`                    | text    | Product title/description                                        |
| `quantity`                 | numeric | Number of units purchased in the transaction                     |
| `purchase_price_per_unit`  | numeric | Price per unit (USD) at time of purchase                          |
| `state_x`                  | text    | US state associated with the purchase                            |
| `year`                     | integer | Year of purchase                                                  |
| `month`                    | text    | Month of purchase, 3-letter abbreviation (e.g., "Dec")            |
| `day`                      | integer | Day of month of purchase                                          |
| `brand`                    | text    | Product brand                                                     |
| `age`                      | text    | Respondent age bracket (e.g., "35 - 44 years")                    |
| `hispanic`                 | text    | Respondent Hispanic/Latino identification (Yes/No)                |
| `race`                     | text    | Respondent race/ethnicity                                          |
| `education`                | text    | Respondent highest education level                                 |
| `income`                   | text    | Respondent household income bracket                                |
| `gender`                   | text    | Respondent gender                                                   |
| `no_of_users`              | text    | Household size / number of account users                          |
| `family_size`              | text    | Respondent family size bracket                                     |

## Example row (fabricated, for illustration only)

| Column | Example value |
|---|---|
| user_id | `R_exampleUser001` |
| product_id | `B00EXAMPLE1` |
| category | Electronics |
| title | Example Wireless Mouse |
| quantity | 1 |
| purchase_price_per_unit | 15.99 |
| state_x | NJ |
| year | 2019 |
| month | Jun |
| day | 14 |
| brand | ExampleBrand |
| age | 25 - 34 years |
| hispanic | No |
| race | White |
| education | Bachelor's degree |
| income | $50,000 - $74,999 |
| gender | Female |
| no_of_users | 1 (just me!) |
| family_size | 2 |

## Derived fields (created in `rfm_analysis.sql`)

| Field | Source view | Description |
|---|---|---|
| `order_value` | `base` | `quantity * purchase_price_per_unit` |
| `purchase_date` | `base` | Combined DATE field parsed from year/month/day |
| `recency_days` | `rfm_base` | Days since user's most recent purchase (relative to latest date in dataset) |
| `frequency` | `rfm_base` | Count of transactions per user |
| `monetary` | `rfm_base` | Total spend per user |
| `r_score`, `f_score`, `m_score` | `rfm_scores` | Quintile scores (1-5, NTILE) per RFM dimension |
| `segment_label` | `rfm_segments` | Business-labeled customer segment (Champions, Loyal Customers, At Risk, etc.) |
