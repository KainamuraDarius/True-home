#!/bin/bash
# Quick script to connect to True Home database
export PGPASSWORD='true_home_pass123'
psql -h localhost -U true_home_user -d true_home_db
