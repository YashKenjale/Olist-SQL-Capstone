# Olist E-Commerce SQL Analysis

## Project Overview

This project analyzes the Olist Brazilian E-Commerce dataset using Microsoft SQL Server to uncover insights into sales, customers, products, sellers, payments, and delivery performance.

The project covers data validation, relational database design, SQL analysis, KPI development, and business insight generation.

The analysis focuses on understanding sales performance, customer retention, delivery efficiency, seller performance, payment behavior, and product trends.

## Tools & Technologies

- Microsoft SQL Server
- SQL Server Management Studio (SSMS)
- T-SQL
- GitHub

## Database Design

The project uses a relational database structure designed for analytical querying.

The main relationships include:

- Customers → Orders
- Orders → Order Items
- Orders → Payments
- Orders → Reviews
- Order Items → Products
- Order Items → Sellers
- Products → Category Translation

### Entity Relationship Diagram

![Olist Database ER Diagram](images/olist_er_diagram.png)

## Dataset

The project uses the Olist Brazilian E-Commerce Public Dataset.

The dataset contains approximately 100K orders and includes information about:

- Customers
- Orders
- Order items
- Products
- Sellers
- Payments
- Reviews
- Product categories
- Geolocation

The raw CSV files were imported into SQL Server and transformed into a clean analytical layer while preserving the original raw tables.
