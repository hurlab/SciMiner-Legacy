# Quick Start Guide: Modern Query Processing System

This guide shows how to replace the legacy Perl mining scripts with the modern Python-based system.

## Problem with Current System

The legacy Perl scripts have several issues:
- **No error handling**: Scripts can hang indefinitely
- **No timeouts**: Failed jobs must be manually killed
- **No monitoring**: Difficult to track progress
- **Single-threaded**: Processes queries sequentially
- **Poor logging**: Minimal visibility into failures

## Modern Solution Overview

The new Python system provides:
- ✅ Async processing with multiple workers
- ✅ Timeout protection (1 hour default)
- ✅ Comprehensive error handling
- ✅ Real-time progress tracking
- ✅ Automatic retries and recovery
- ✅ Resource monitoring
- ✅ REST API for management

## Quick Migration Steps

### 1. Stop Legacy Perl Scripts

```bash
# Find running Perl processes
ps aux | grep MonitorSciMiner

# Kill them safely
pkill -f MonitorSciMinerQueue.pl
pkill -f MonitorSciMinerAnalysis.pl
pkill -f MonitorSciMinerGRIFQueue.pl
```

### 2. Start the Modern System

```bash
# Using Docker (recommended)
cd /home/sciminer
./deploy.sh start

# Or directly
cd backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Verify the Processor is Running

```bash
# Check processor status
curl -X GET "http://localhost:8000/processor/status" \
  -H "Authorization: Bearer <admin-token>"

# Expected response:
{
  "is_running": true,
  "active_jobs": 0,
  "queued_jobs": 0,
  "max_concurrent_jobs": 5,
  "workers": ["query-processor-worker-0", ...]
}
```

### 4. Submit a Test Query

```bash
# Submit a query through the API
curl -X POST "http://localhost:8000/queries" \
  -H "Authorization: Bearer <user-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Query",
    "description": "Testing modern processor",
    "pubmed_query": "TP53[gene] AND cancer",
    "genes": [{"symbol": "TP53"}],
    "filters": {"max_documents": 10}
  }'

# Execute the query
curl -X POST "http://localhost:8000/queries/1/execute" \
  -H "Authorization: Bearer <user-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "max_documents": 10,
    "include_fulltext": true
  }'
```

### 5. Monitor Progress

```bash
# Check job status
curl -X GET "http://localhost:8000/processor/jobs/1" \
  -H "Authorization: Bearer <admin-token>"

# Expected response:
{
  "query_id": 1,
  "status": "running",
  "progress": 65,
  "current_step": "Processing documents",
  "worker": "worker-2"
}
```

## Configuration Options

### Environment Variables

Add to `.env`:

```bash
# Query processor settings
QUERY_PROCESSOR_MAX_WORKERS=10
QUERY_PROCESSOR_TIMEOUT=3600
QUERY_PROCESSOR_USE_LEGACY=true
```

### Runtime Options

The processor supports three modes:

1. **Legacy Mode** (default for compatibility)
   - Runs existing Perl scripts with supervision
   - Provides timeout protection
   - Adds modern monitoring

2. **Modern Mode** (recommended for new deployments)
   - Pure Python processing
   - Better error handling
   - Faster execution

3. **Hybrid Mode** (gradual migration)
   - Use Python for fetching
   - Use Perl for mining logic
   - Easy fallback option

## API Endpoints

### Processor Management

```bash
# Start/stop processor
POST /processor/start
POST /processor/stop
POST /processor/restart

# Get status
GET /processor/status

# Manage jobs
GET /processor/jobs
GET /processor/jobs/{query_id}
POST /processor/jobs/{query_id}/cancel
```

### Query Execution

```bash
# Create and execute queries
POST /queries
POST /queries/{id}/execute

# Check progress
GET /queries/{id}
GET /queries/{id}/documents
```

## Monitoring and Debugging

### Logs

```bash
# View processor logs
docker-compose logs -f backend

# Look for these patterns:
# - "Processing query X"
# - "Worker Y processing job Z"
# - "Job X timed out"
# - "Job X failed: error"
```

### Common Issues

1. **Jobs stuck in "running" state**
   - Check if processor is running: `/processor/status`
   - Restart processor: `/processor/restart`
   - Cancel stuck job: `/processor/jobs/{id}/cancel`

2. **Legacy script not found**
   - Verify path: `/home/sciminer/ANNOTATION/SciMinerDB/Scripts/Main/`
   - Check permissions: `ls -la *.pl`
   - Install Perl dependencies if needed

3. **Memory issues**
   - Reduce concurrent workers: `QUERY_PROCESSOR_MAX_WORKERS=2`
   - Monitor with: `docker stats`

## Performance Benefits

| Metric | Legacy Perl | Modern Python |
|--------|-------------|---------------|
| Concurrent Jobs | 1 | 5-10 (configurable) |
| Timeout Protection | ❌ | ✅ (1 hour) |
| Error Recovery | Manual | Automatic |
| Progress Tracking | ❌ | ✅ Real-time |
| Memory Usage | High | Optimized |
| API Integration | ❌ | ✅ RESTful |

## Next Steps

1. **Gradual Migration**
   - Start with legacy mode for safety
   - Monitor for 1 week
   - Switch to modern mode gradually

2. **Performance Tuning**
   - Adjust worker count based on server resources
   - Optimize timeout for typical query sizes
   - Add caching for repeated queries

3. **Enhancements**
   - WebSocket for real-time updates
   - Email notifications for failures
   - Query priority system
   - Distributed processing with Celery

## Support

For issues with the modern processor:
1. Check logs: `docker-compose logs backend`
2. Verify API endpoints: `/docs`
3. Create issue with:
   - Error messages
   - Query details
   - System resources
   - Steps to reproduce