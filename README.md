# marketing_analysis
Проект для анализа данных маркетинговых компаний

Проект по анализу данных для оценки маркетинговых каналов интернет-магазина. 
Включает полный цикл: проектирование БД, генерацию тестовых данных, аналитические запросы и визуализацию.

##  О проекте

Цель проекта — продемонстрировать навыки работы с данными

## Технологический стек
База данных: Microsoft SQL Server 2019+

Язык запросов: T-SQL

Инструменты: SQL Server Management Studio (SSMS)

Визуализация: Power BI (опционально)

Контроль версий: Git

##  Структура базы данных

База данных состоит из 7 связанных таблиц:

```mermaid
    
    users {
        int user_id PK
        varchar email
        date registration_date
        varchar country
        varchar city
        int age
        varchar gender
    }
    
    marketing_touch {
        int touch_id PK
        int user_id FK
        datetime touch_date
        varchar channel
        varchar campaign_name
        varchar device_type
        decimal ad_cost
    }
    
    sessions {
        int session_id PK
        int user_id FK
        datetime session_date
        int session_duration
        int pages_viewed
        varchar traffic_source
    }
    
    products {
        int product_id PK
        varchar product_name
        varchar category
        decimal price
        decimal cost
    }
    
    orders {
        int order_id PK
        int user_id FK
        datetime order_date
        varchar status
        decimal total_amount
        decimal discount
    }
    
    order_items {
        int order_item_id PK
        int order_id FK
        int product_id FK
        int quantity
        decimal price
        decimal cost
    }
    
    marketing_costs {
        int cost_id PK
        varchar channel
        date cost_date
        int impressions
        int clicks
        decimal total_cost
    }
