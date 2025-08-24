# Community Solar Garden Management System

A comprehensive blockchain-based system for managing community solar gardens, built on the Stacks blockchain using Clarity smart contracts.

## Overview

This system enables communities to collectively own and manage solar installations through a decentralized platform that handles:

- **Solar Panel Ownership & Investment Tracking**: Track individual and collective investments in solar infrastructure
- **Energy Production Allocation**: Distribute generated energy credits among subscribers based on their ownership stakes
- **Billing Integration**: Interface with utility companies for seamless billing and credit management
- **Maintenance Coordination**: Coordinate maintenance activities and distribute costs fairly among stakeholders
- **Environmental Impact Reporting**: Track carbon credits and environmental benefits

## System Architecture

The system consists of five interconnected Clarity smart contracts:

### 1. Solar Panel Management (`solar-panel-manager.clar`)
- Manages solar panel registration and ownership
- Tracks panel specifications, installation dates, and performance metrics
- Handles panel lifecycle management

### 2. Subscriber Management (`subscriber-manager.clar`)
- Manages subscriber registration and profiles
- Tracks investment amounts and ownership percentages
- Handles subscriber status and permissions

### 3. Energy Production (`energy-production.clar`)
- Records daily energy production data
- Calculates energy allocation based on ownership stakes
- Manages energy credit distribution

### 4. Billing System (`billing-system.clar`)
- Interfaces with utility billing cycles
- Calculates credits and charges for subscribers
- Manages payment processing and reconciliation

### 5. Maintenance Coordinator (`maintenance-coordinator.clar`)
- Schedules and tracks maintenance activities
- Distributes maintenance costs among subscribers
- Manages service provider relationships

## Key Features

### Investment Tracking
- Transparent investment recording
- Proportional ownership calculation
- Investment history and returns tracking

### Energy Allocation
- Real-time production monitoring
- Fair distribution algorithms
- Credit accumulation and usage tracking

### Billing Integration
- Automated utility bill processing
- Credit application and reconciliation
- Payment status tracking

### Maintenance Management
- Preventive maintenance scheduling
- Cost sharing based on ownership
- Service quality tracking

### Environmental Impact
- Carbon footprint reduction tracking
- Renewable energy certificate management
- Sustainability reporting

## Data Types

### Core Structures

```clarity
;; Solar Panel
{
  panel-id: uint,
  capacity-watts: uint,
  installation-date: uint,
  location: (string-ascii 100),
  status: (string-ascii 20),
  total-production: uint
}

;; Subscriber
{
  subscriber-id: principal,
  investment-amount: uint,
  ownership-percentage: uint,
  join-date: uint,
  status: (string-ascii 20),
  energy-credits: uint
}

;; Energy Production Record
{
  date: uint,
  panel-id: uint,
  production-kwh: uint,
  weather-conditions: (string-ascii 50)
}
