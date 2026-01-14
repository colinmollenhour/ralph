# Task Priority System

## Overview
Add priority levels to tasks so users can focus on what matters most. Tasks can be marked as high, medium, or low priority.

## Goals
- Allow assigning priority (high/medium/low) to any task
- Provide clear visual differentiation between priority levels
- Enable filtering and sorting by priority
- Default new tasks to medium priority

## User Stories
- US-001: Add priority field to database
- US-002: Display priority indicator on task cards
- US-003: Add priority selector to task edit
- US-004: Filter tasks by priority

## Technical Notes
- Priority stored as enum: 'high' | 'medium' | 'low'
- Default value: 'medium'
- Badge colors: red=high, yellow=medium, gray=low
- Filter persists in URL params
