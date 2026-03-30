# SciMiner Modernization Plan v2
**Date:** 2025-12-09
**Status:** Planning Phase

## Executive Summary

This modernization plan addresses critical updates needed for SciMiner, focusing on:
1. Complete frontend overhaul to modern web standards
2. Secure and robust user management system
3. Enhanced document retrieval with PMC Central integration
4. Updated text parsers for current journal layouts

## Current State Analysis

### Critical Security Issues Identified
- **Plain text passwords** in database
- **No session management** beyond basic cookies
- **SQL injection vulnerabilities**
- **No input validation**
- **File-based session storage**

### Frontend Assessment
- **Frames-based UI** (banner, menu, detail) - obsolete since HTML5
- **Vanilla JavaScript** with minimal functionality
- **No responsive design**
- **Inline CSS** - no maintainable styling
- **13MB HTML templates** - indicates poor structure

### Backend Architecture
- **30+ CGI scripts** with duplicated code
- **Perl 5.38** with outdated practices
- **No API layer** - direct CGI execution
- **Hardcoded paths** throughout codebase
- **No error handling** framework

### Document Processing
- **PubMed E-utilities** integration present
- **No PMC Central API** integration
- **MEDLINE parser** from 2008
- **Local document storage** with no optimization

## Modernization Priorities

### Priority 1: Security & Stability (2 weeks)
**Timeline:** Immediate - Week 1-2

1. **Security Fixes**
   - Implement bcrypt password hashing
   - Create secure session management
   - Add input validation and sanitization
   - Implement prepared statements for all SQL queries
   - Add CSRF protection
   - Move credentials to environment variables

2. **Database Migration**
   - Create migration scripts for password hashing
   - Add proper database indexes
   - Implement database connection pooling

3. **Error Handling**
   - Add comprehensive error logging
   - Create user-friendly error pages
   - Implement proper HTTP status codes

### Priority 2: Frontend Modernization (8 weeks)
**Timeline:** Week 3-10

#### Technology Stack
- **React 18** with TypeScript
- **Material-UI v5** for components
- **React Router** for navigation
- **Zustand** for state management
- **React Query** for server state
- **Axios** for API communication

#### Component Architecture
```
src/
├── components/
│   ├── Layout/
│   │   ├── AppLayout.tsx      # Replace frames
│   │   ├── Header.tsx
│   │   ├── Sidebar.tsx
│   │   └── Footer.tsx
│   ├── Auth/
│   │   ├── Login.tsx
│   │   ├── Register.tsx
│   │   └── Profile.tsx
│   ├── Query/
│   │   ├── QueryBuilder.tsx
│   │   ├── QueryHistory.tsx
│   │   └── QueryResults.tsx
│   ├── Analysis/
│   │   ├── ResultsTable.tsx
│   │   ├── NetworkGraph.tsx
│   │   └── GeneList.tsx
│   └── Documents/
│       ├── DocumentViewer.tsx
│       ├── FullTextViewer.tsx
│       └── ExportOptions.tsx
├── pages/
├── hooks/
├── services/
└── utils/
```

#### Implementation Steps
1. **Week 3-4**: Setup React project, create layout components
2. **Week 5-6**: Implement authentication and user management
3. **Week 7**: Migrate query builder and results display
4. **Week 8**: Add network visualization and responsive design
5. **Week 9-10**: Testing, optimization, and deployment

### Priority 3: User Management System Overhaul (3 weeks)
**Timeline:** Week 3-5 (parallel with frontend)

#### Authentication System
```typescript
interface User {
  id: number;
  email: string;
  passwordHash: string;
  role: 'admin' | 'user' | 'viewer';
  orcid?: string;
  preferences: UserPreferences;
}

interface Session {
  userId: number;
  token: string;
  expiresAt: Date;
  lastActivity: Date;
}
```

#### Features
1. **Multi-factor Authentication**
   - Email verification
   - Optional TOTP (Google Authenticator)
   - ORCID integration for researchers

2. **Role-based Access Control**
   - Admin: Full access
   - User: Personal analyses
   - Viewer: Read-only access

3. **Enhanced User Profile**
   - Saved queries
   - Analysis history
   - Export preferences
   - API key management

### Priority 4: Document Handling Enhancement (4 weeks)
**Timeline:** Week 6-9

#### PMC Central Integration
```python
# Pseudo-code for PMC Central integration
class DocumentFetcher:
    def fetch_document(pmid: str):
        # Try PMC Central first (open access)
        if pmc_id := self.get_pmc_id(pmid):
            return self.fetch_pmc_full_text(pmc_id)

        # Fall back to publisher site
        return self.fetch_publisher_full_text(pmid)
```

#### Enhanced Parser System
1. **Modular Parsers**
   - Each journal gets dedicated parser class
   - Version-controlled for layout changes
   - Fallback to generic HTML parser

2. **Journal-Specific Parsers**
   ```python
   class NatureParser(BaseParser):
       def extract_abstract(self):
           # Nature-specific selectors

       def extract_full_text(self):
           # Nature article structure
   ```

3. **Supported Publishers**
   - Nature Publishing Group
   - Science (AAAS)
   - Cell Press
   - Elsevier (ScienceDirect)
   - Wiley Online Library
   - Springer
   - Oxford Academic

#### Document Queue System
- **Redis queue** for async processing
- **WebSocket updates** for progress
- **S3 storage** for document cache
- **Deduplication** based on DOI

### Priority 5: API Development (4 weeks)
**Timeline:** Week 6-9 (parallel with document handling)

#### REST API Endpoints
```typescript
// Authentication
POST   /api/auth/login
POST   /api/auth/register
POST   /api/auth/logout
GET    /api/auth/profile

// Queries
GET    /api/queries
POST   /api/queries
GET    /api/queries/:id
DELETE /api/queries/:id

// Documents
GET    /api/documents/:pmid
POST   /api/documents/fetch
GET    /api/documents/:pmid/fulltext

// Analyses
GET    /api/analyses
POST   /api/analyses
GET    /api/analyses/:id
GET    /api/analyses/:id/network
GET    /api/analyses/:id/genes
```

#### API Features
- JWT authentication
- Rate limiting
- CORS configuration
- OpenAPI documentation
- Pagination support

## Implementation Strategy

### Development Workflow
1. **Feature Branches** for each component
2. **Pull Requests** for code review
3. **CI/CD Pipeline** for automated testing
4. **Staging Environment** for user testing

### Migration Approach
1. **Parallel Development**
   - Keep existing CGI running
   - New API and frontend developed separately
   - Gradual component migration

2. **Feature Flags**
   - Toggle between old/new UI
   - A/B testing for features
   - Rollback capability

3. **Database Versioning**
   - Alembic or Flyway migrations
   - Forward/backward compatibility
   - Zero-downtime deployments

## Testing Strategy

### Frontend Testing
- Jest for unit tests
- React Testing Library
- Cypress for E2E tests
- Storybook for component documentation

### Backend Testing
- Python pytest or Perl Test::More
- API contract testing
- Database integration tests
- Performance testing

### Security Testing
- OWASP ZAP scans
- Penetration testing
- Dependency vulnerability scanning
- Code security review

## Performance Optimizations

### Frontend
- Code splitting
- Lazy loading
- Service workers for caching
- CDN for static assets

### Backend
- Database query optimization
- Redis caching layer
- Async processing queues
- Connection pooling

## Deployment Architecture

### Production Stack
```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Nginx     │  │   React     │  │   API       │
│ (SSL/TLS)   │──│   SPA       │──│  (Python/   │
│             │  │             │  │   FastAPI)  │
└─────────────┘  └─────────────┘  └─────────────┘
                                            │
                       ┌─────────────┐  ┌─────────────┐
                       │  MariaDB     │  │    Redis    │
                       │   (Primary)  │  │   (Cache)   │
                       └─────────────┘  └─────────────┘
```

### Infrastructure
- Docker containers
- Kubernetes orchestration
- AWS S3 for document storage
- CloudFront CDN
- CloudWatch for monitoring

## Resource Requirements

### Team Composition
- **Frontend Developer** (React/TypeScript)
- **Backend Developer** (Python/FastAPI or Perl Mojolicious)
- **DevOps Engineer** (Docker/K8s)
- **Security Specialist** (audit/review)
- **QA Engineer** (testing)

### Timeline Summary
- **Phase 1 (Security)**: 2 weeks
- **Phase 2 (Frontend)**: 8 weeks
- **Phase 3 (User Management)**: 3 weeks (parallel)
- **Phase 4 (Documents)**: 4 weeks (parallel)
- **Phase 5 (API)**: 4 weeks (parallel)
- **Testing & Deployment**: 2 weeks

**Total Estimated Time:** 12-14 weeks

## Success Metrics

### Technical Metrics
- Page load time < 2 seconds
- API response time < 500ms
- 99.9% uptime
- Zero critical vulnerabilities

### User Experience Metrics
- User task completion rate > 95%
- Session duration increase
- Reduced support tickets
- Positive user feedback

## Risk Mitigation

### Technical Risks
- **Data Migration**: Comprehensive backup strategy
- **Downtime**: Blue-green deployment
- **Performance**: Load testing before release
- **Security**: Regular audits and updates

### Business Risks
- **User Adoption**: Gradual rollout with training
- **Feature Loss**: Comprehensive feature parity
- **Cost**: Cloud optimization strategies

---

## Next Steps

1. **Approve Plan** - Review and finalize priorities
2. **Setup Team** - Assign developers and roles
3. **Setup Infrastructure** - Create development environments
4. **Begin Phase 1** - Start security improvements
5. **Weekly Reviews** - Progress tracking and adjustments

*This plan will be updated regularly as implementation progresses.*