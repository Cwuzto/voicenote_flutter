-- 006_reset_all_demo_data.sql
-- WARNING:
-- This script deletes ALL app data in the public schema for this project.
-- It does NOT delete rows in auth.users, but it does clear mirrored app data
-- in public.users, stores, employees, products, orders, bank accounts,
-- speaker templates, and order items.
--
-- Recommended flow after running:
-- 1. Run this file
-- 2. Run 005_add_paid_by_user_to_orders.sql (if not applied yet)
-- 3. Run 003_seed_demo.sql

begin;

delete from public.order_items;
delete from public.orders;
delete from public.employees;
delete from public.products;
delete from public.bank_accounts;
delete from public.speaker_templates;
delete from public.stores;
delete from public.users;

commit;
