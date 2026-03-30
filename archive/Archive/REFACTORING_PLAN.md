# SciMiner Refactoring Plan

## Overview
SciMiner is a legacy web-based biomedical literature mining tool from ~2008 built with Perl/CGI. This document outlines a comprehensive refactoring plan to modernize the system from frontend to backend.

## Current Architecture Analysis

### Frontend Issues
1. **Frames-based HTML** - Obsolete, not SEO-friendly, poor UX
2. **No JavaScript Framework** - Vanilla JS only, no interactivity
3. **Static Styling** - Inline CSS, no responsive design
4. **No REST API** - Direct CGI interface
5. **Poor UI/UX** - Outdated interface design

### Backend Issues
1. **Perl CGI** - Legacy, not maintainable
2. **Modular but Coupled** - Tight coupling between modules
3. **No ORM** - Direct SQL queries
4. **Session Management** - File-based, not secure
5. **No Testing** - No unit or integration tests
6. **No Error Handling** - Poor error management
7. **Hardcoded Paths** - Not portable
8. **Security Issues** - Potential vulnerabilities

### Database Issues
1. **MySQL/MariaDB** - Could be optimized
2. **No Migrations** - Schema changes not tracked
3. **No Caching** - Direct database queries
4. **Large Dumps** - Inefficient data loading

## Refactoring Goals

### Phase 1: Stabilization & Documentation
1. Fix immediate bugs and issues
2. Document existing codebase
3. Set up proper testing environment
4. Implement basic error handling
5. Add logging throughout

### Phase 2: Backend Modernization
1. **API Development**
   - Create RESTful API endpoints
   - Implement JSON responses
   - Add API authentication
   - Version the API (v1, v2)

2. **Database Layer**
   - Implement ORM (DBIx::Class or similar)
   - Add database migrations
   - Optimize queries
   - Implement caching (Redis/Memcached)

3. **Business Logic**
   - Extract business logic from CGI
   - Create service layer
   - Implement proper error handling
   - Add comprehensive logging

### Phase 3: Frontend Modernization
1. **Technology Stack**
   - React.js for UI
   - TypeScript for type safety
   - Material-UI or Ant Design for components
   - Redux/Zustand for state management
   - React Router for navigation

2. **Features**
   - Single Page Application (SPA)
   - Responsive design
   - Real-time updates (WebSockets)
   - Progressive Web App (PWA) features

### Phase 4: DevOps & Infrastructure
1. **Containerization**
   - Docker containers
   - Docker Compose for development
   - Kubernetes for production

2. **CI/CD Pipeline**
   - GitHub Actions
   - Automated testing
   - Automated deployment
   - Code quality checks

3. **Monitoring & Observability**
   - Application monitoring
   - Performance metrics
   - Error tracking
   - Health checks

## Detailed Implementation Plan

### Phase 1: Stabilization (Weeks 1-2)

#### 1.1 Bug Fixes
- [ ] Fix Boulder::Medline line 274 issue
- [ ] Resolve missing Perl module dependencies
- [ ] Fix authentication issues
- [ ] Patch security vulnerabilities

#### 1.2 Documentation
- [ ] Code documentation for all modules
- [ ] API documentation (current CGI)
- [ ] Database schema documentation
- [ ] Installation guide updates

#### 1.3 Testing Setup
- [ ] Unit test framework setup
- [ ] Basic tests for core modules
- [ ] Integration test skeleton
- [ ] Test data setup

#### 1.4 Infrastructure
- [ ] Git repository initialization
- [ ] Development environment setup
- [ ] CI pipeline basic configuration
- [ ] Code quality tools (perlcritic, prettier)

### Phase 2: Backend Refactoring (Weeks 3-6)

#### 2.1 API Layer
```perl
# New API Structure
/sciminer/api/v1/
├── /auth/
│   ├── POST /login
│   ├── POST /logout
│   └── GET /profile
├── /queries/
│   ├── GET / - List queries
│   ├── POST / - Create query
│   ├── GET /:id - Get query
│   ├── PUT /:id - Update query
│   └── DELETE /:id - Delete query
├── /analysis/
│   ├── POST / - Start analysis
│   ├── GET /:id - Get analysis status
│   └── GET /:id/results - Get results
└── /export/
    ├── GET /csv/:id
    ├── GET /excel/:id
    └── GET /network/:id
```

#### 2.2 Service Layer
```perl
# Service::Query
- create_query()
- execute_query()
- get_query()
- list_queries()
- delete_query()

# Service::Analysis
- start_analysis()
- get_analysis_status()
- get_results()
- cancel_analysis()

# Service::Export
- export_csv()
- export_excel()
- generate_network()
```

#### 2.3 Data Access Layer
```perl
# Model::Query
- Primary database operations
- Validation
- Relationships

# Model::Analysis
- Analysis tracking
- Result storage
- Status management

# Model::User
- User management
- Authentication
- Authorization
```

### Phase 3: Frontend Refactoring (Weeks 7-12)

#### 3.1 Project Structure
```
frontend/
├── public/
│   ├── index.html
│   └── favicon.ico
├── src/
│   ├── components/
│   │   ├── common/
│   │   ├── query/
│   │   ├── analysis/
│   │   └── export/
│   ├── pages/
│   │   ├── Home/
│   │   ├── QueryBuilder/
│   │   ├── Results/
│   │   └── Settings/
│   ├── services/
│   │   ├── api.ts
│   │   ├── auth.ts
│   │   └── websocket.ts
│   ├── store/
│   │   ├── index.ts
│   │   └── slices/
│   ├── types/
│   │   └── index.ts
│   └── utils/
│       └── helpers.ts
├── package.json
└── tsconfig.json
```

#### 3.2 Component Breakdown

##### 3.2.1 Layout Components
- **AppHeader**: Navigation and user menu
- **AppSidebar**: Quick actions and filters
- **AppFooter**: Links and information
- **AppLayout**: Main layout wrapper

##### 3.2.2 Query Components
- **QueryBuilder**: Drag-and-drop query interface
- **QueryHistory**: Previous queries list
- **QueryPreview**: Live preview of results
- **SavedQueries**: Manage saved queries

##### 3.2.3 Analysis Components
- **AnalysisProgress**: Real-time progress bar
- **ResultsTable**: Sortable, filterable results
- **NetworkVisualization**: Interactive network graph
- **StatisticsPanel**: Analysis statistics

##### 3.2.4 Export Components
- **ExportOptions**: Format selection
- **DownloadManager**: Track downloads
- **ShareDialog**: Share results

#### 3.3 State Management
```typescript
// Store Structure
interface AppState {
  auth: {
    user: User | null;
    token: string | null;
    isAuthenticated: boolean;
  };
  queries: {
    current: Query | null;
    history: Query[];
    loading: boolean;
  };
  analysis: {
    active: Analysis | null;
    results: Result[];
    progress: number;
  };
  ui: {
    sidebarOpen: boolean;
    theme: 'light' | 'dark';
  };
}
```

### Phase 4: Advanced Features (Weeks 13-16)

#### 4.1 Real-time Features
- WebSocket connection for live updates
- Progress indicators for long-running analyses
- Real-time collaboration

#### 4.2 Advanced Analytics
- Interactive visualizations
- Statistical analysis tools
- Custom report generation

#### 4.3 Mobile Support
- Responsive design
- Mobile app (React Native)
- Touch-friendly interface

#### 4.4 Performance
- Lazy loading
- Virtual scrolling
- Caching strategies
- CDN integration

## Migration Strategy

### 1. Parallel Development
- Keep old system running
- Develop new system in parallel
- Feature flag for gradual migration
- A/B testing for validation

### 2. Database Migration
- Create migration scripts
- Run in production with backups
- Validate data integrity
- Rollback procedures

### 3. User Migration
- Export user data from old system
- Import to new system
- Password reset workflow
- User communication plan

## Technology Choices

### Backend
- **Language**: Perl 5+ (maintain compatibility)
- **Framework**: Mojolicious or Dancer2
- **ORM**: DBIx::Class
- **API**: REST with OpenAPI spec
- **Auth**: JWT tokens
- **Cache**: Redis
- **Queue**: Minion or RabbitMQ

### Frontend
- **Framework**: React 18+ with TypeScript
- **UI Library**: Material-UI v5
- **State**: Zustand
- **Routing**: React Router v6
- **HTTP Client**: Axios
- **Charts**: D3.js or Chart.js

### DevOps
- **Container**: Docker
- **CI/CD**: GitHub Actions
- **Monitor**: Prometheus + Grafana
- **Logs**: ELK Stack

## Implementation Checklist

### Week 1
- [ ] Setup git repository
- [ ] Fix immediate bugs
- [ ] Create development environment
- [ ] Setup basic CI

### Week 2
- [ ] Document existing code
- [ ] Install missing dependencies
- [ ] Create test skeleton
- [ ] Fix Boulder::Medline issue

### Week 3
- [ ] Design API structure
- [ ] Implement authentication service
- [ ] Create basic API endpoints
- [ ] Setup database ORM

### Week 4
- [ ] Migrate query logic to services
- [ ] Implement analysis service
- [ ] Add comprehensive logging
- [ ] Create API documentation

### Week 5
- [ ] Setup frontend project
- [ ] Create basic components
- [ ] Implement routing
- [ ] Setup state management

### Week 6
- [ ] Build query interface
- [ ] Implement results display
- [ ] Add export functionality
- [ ] Create user dashboard

### Week 7
- [ ] Add real-time updates
- [ ] Implement collaboration
- [ ] Performance optimization
- [ ] Security audit

### Week 8
- [ ] User testing
- [ ] Bug fixes
- [ ] Documentation
- [ ] Deployment preparation

## Success Metrics

### Technical Metrics
- Code coverage > 80%
- API response time < 200ms
- Page load time < 3s
- Zero security vulnerabilities

### User Metrics
- User satisfaction > 4/5
- Task completion time reduced by 50%
- Error rate < 1%
- Mobile usability score > 85

## Risks & Mitigations

### Technical Risks
- **Perl expertise shortage**: Document thoroughly, consider partial rewrite
- **Data migration**: Create comprehensive test suite
- **Performance**: Implement caching from day one
- **Security**: Regular security audits

### Project Risks
- **Timeline**: Start with MVP, iterate
- **Resources**: Prioritize features
- **User adoption**: Involve users early
- **Technical debt**: Regular refactoring sessions

## Conclusion

This refactoring plan provides a roadmap to modernize SciMiner while maintaining its core functionality. The phased approach minimizes risk and allows for iterative improvements. The key is to maintain backward compatibility while gradually introducing modern features and technologies.