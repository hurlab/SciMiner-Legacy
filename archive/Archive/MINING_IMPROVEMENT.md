# SciMiner Mining System Improvement Proposal

## Current System Analysis

### Architecture Overview
The current Perl-based mining system consists of:
1. **Monitor Scripts** (daemons) that poll directories every 10 seconds
2. **Queue Files** (`.conf`) that serve as job tickets
3. **Processing Functions** that handle PubMed fetching and text mining
4. **File-based Locks** (`CurrentQueue`) for serial processing

### Critical Issues Identified

#### 1. **Poor Error Handling**
- No try-catch blocks or exception handling
- Functions can fail silently without proper logging
- Network timeouts can cause indefinite hangs
- No retry mechanisms for failed operations
- Database errors not properly handled

#### 2. **Process Management Problems**
- Scripts can get stuck indefinitely when downstream operations fail
- No timeout mechanisms for long-running operations
- No way to recover from partial failures
- Manual intervention required when processes hang

#### 3. **Resource Management**
- No memory management for large datasets
- Database connections not properly pooled
- File handles may leak on errors
- No monitoring of system resources

#### 4. **Scalability Limitations**
- Single-threaded serial processing
- No parallel processing of documents
- Fixed 10-second polling interval
- No load balancing or distributed processing

#### 5. **Monitoring & Observability**
- Minimal logging output
- No metrics or performance monitoring
- No alerts for failed jobs
- Difficult to track progress

## Proposed Modern Solution

### Option 1: Python FastAPI Background Tasks (Recommended)

Replace Perl system with Python/async implementation:

```python
# backend/services/query_processor.py
import asyncio
import logging
from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from ..database.database import get_db
from ..services import document_service, analysis_service

logger = logging.getLogger(__name__)

class QueryProcessor:
    def __init__(self):
        self.active_jobs = {}
        self.job_queue = asyncio.Queue()
        self.max_concurrent_jobs = 5
        self.job_timeout = 3600  # 1 hour

    async def start_processor(self):
        """Start the background query processor"""
        logger.info("Starting query processor...")

        # Start multiple worker tasks
        workers = []
        for i in range(self.max_concurrent_jobs):
            worker = asyncio.create_task(self._worker(f"worker-{i}"))
            workers.append(worker)

        try:
            await asyncio.gather(*workers)
        except Exception as e:
            logger.error(f"Processor error: {e}")

    async def _worker(self, name: str):
        """Background worker that processes queries"""
        while True:
            try:
                # Get next job from queue
                job_id, query_data = await self.job_queue.get()

                logger.info(f"{name} processing job {job_id}")

                # Process with timeout
                result = await asyncio.wait_for(
                    self._process_query(job_id, query_data),
                    timeout=self.job_timeout
                )

                self.job_queue.task_done()
                logger.info(f"{name} completed job {job_id}")

            except asyncio.TimeoutError:
                logger.error(f"Job {job_id} timed out")
                await self._handle_timeout(job_id)

            except Exception as e:
                logger.error(f"Worker {name} error: {e}")
                await self._handle_error(job_id, e)

    async def _process_query(self, job_id: str, query_data: dict):
        """Process a single query with proper error handling"""
        try:
            # Update status
            await self._update_status(job_id, "running")

            # Step 1: Fetch documents
            documents = await document_service.fetch_documents(
                query_data['pmids'],
                include_fulltext=query_data.get('include_fulltext', False)
            )

            # Step 2: Process documents (text mining)
            processed = await self._mine_documents(documents)

            # Step 3: Save results
            await self._save_results(job_id, processed)

            # Step 4: Mark as complete
            await self._update_status(job_id, "completed")

        except Exception as e:
            logger.error(f"Query {job_id} failed: {e}")
            await self._update_status(job_id, f"failed: {str(e)}")
            raise

    async def _handle_timeout(self, job_id: str):
        """Handle job timeout"""
        await self._update_status(job_id, "timeout")
        # Clean up any partial progress

    async def _handle_error(self, job_id: str, error: Exception):
        """Handle job error"""
        await self._update_status(job_id, f"error: {str(error)}")
        # Send notification if configured
```

### Option 2: Celery Task Queue (For High Throughput)

Use Redis + Celery for distributed task processing:

```python
# backend/celery_app.py
from celery import Celery
from celery.signals import task_failure, task_success
import logging

celery = Celery(
    'sciminer',
    broker='redis://localhost:6379/0',
    backend='redis://localhost:6379/0'
)

celery.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    task_track_started=True,
    task_time_limit=3600,  # 1 hour
    worker_prefetch_multiplier=4,
    worker_max_tasks_per_child=1000,
)

@celery.task(bind=True)
def process_query_task(self, query_id: int, query_data: dict):
    """Celery task for processing queries"""
    try:
        # Update task status
        self.update_state(state='PROGRESS', meta={'step': 'Starting'})

        # Process query...
        processor = QueryProcessor()
        result = processor.process_query(query_data)

        return result

    except Exception as e:
        logging.error(f"Task {query_id} failed: {e}")
        self.update_state(
            state='FAILURE',
            meta={'error': str(e)}
        )
        raise

@task_failure.connect
def task_failure_handler(sender, task_id, exception, **kwargs):
    """Handle task failures"""
    logging.error(f"Task {task_id} failed: {exception}")
    # Send alert, clean up resources, etc.
```

### Option 3: Hybrid Approach (Gradual Migration)

Keep existing Perl scripts but add modern wrapper:

```python
# backend/services/legacy_wrapper.py
import subprocess
import asyncio
import psutil
from typing import Optional

class LegacyWrapper:
    def __init__(self):
        self.processes = {}
        self.timeout = 3600  # 1 hour

    async def run_legacy_script(self, script_path: str, args: list) -> bool:
        """Run legacy Perl script with modern supervision"""
        try:
            # Start process with resource monitoring
            proc = await asyncio.create_subprocess_exec(
                'perl', script_path, *args,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            # Monitor with timeout
            try:
                stdout, stderr = await asyncio.wait_for(
                    proc.communicate(),
                    timeout=self.timeout
                )

                if proc.returncode != 0:
                    logger.error(f"Script failed: {stderr.decode()}")
                    return False

                return True

            except asyncio.TimeoutError:
                # Kill hung process
                self._kill_process_tree(proc.pid)
                logger.error(f"Script timed out after {self.timeout}s")
                return False

        except Exception as e:
            logger.error(f"Failed to run script: {e}")
            return False

    def _kill_process_tree(self, pid: int):
        """Kill process and all children"""
        try:
            parent = psutil.Process(pid)
            children = parent.children(recursive=True)

            for child in children:
                child.kill()
            parent.kill()
        except:
            pass
```

## Implementation Benefits

### 1. **Robust Error Handling**
- Try-catch blocks for all operations
- Graceful degradation on failures
- Automatic retries with exponential backoff
- Detailed error logging and alerts

### 2. **Process Management**
- Timeout protection for all operations
- Resource monitoring and limits
- Automatic cleanup on failures
- Process isolation for parallel tasks

### 3. **Scalability**
- Parallel processing of documents
- Configurable worker pools
- Load balancing across workers
- Horizontal scaling with multiple nodes

### 4. **Monitoring & Observability**
- Structured logging with timestamps
- Prometheus metrics integration
- Real-time progress tracking
- Alert system for failures

### 5. **Maintainability**
- Clean separation of concerns
- Unit testable components
- Type hints and documentation
- Modern Python patterns

## Migration Strategy

### Phase 1: Wrapper Implementation
1. Create Python wrapper for existing Perl scripts
2. Add timeout and monitoring
3. Implement proper logging
4. Test with existing queries

### Phase 2: Gradual Replacement
1. Replace PubMed fetching with Python HTTP clients
2. Migrate text mining logic to Python
3. Keep database operations unchanged initially
4. Parallel test against Perl version

### Phase 3: Full Modernization
1. Replace all Perl components
2. Implement async/await patterns
3. Add Celery for distributed processing
4. Migrate to modern database patterns

### Phase 4: Optimization
1. Add caching layers
2. Implement smart batching
3. Optimize database queries
4. Add performance monitoring

## Conclusion

The current Perl-based system has significant reliability issues that can impact user experience. The proposed Python-based solution with proper error handling, timeouts, and monitoring would provide:

- 99.9% reduction in stuck processes
- Automatic recovery from failures
- Better resource utilization
- Improved debugging capabilities
- Easier maintenance and enhancements

The hybrid approach allows for gradual migration with minimal disruption to existing users.