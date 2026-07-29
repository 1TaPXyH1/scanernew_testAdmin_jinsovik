You are the lead auditor responsible for conducting a complete, independent, evidence-based audit of this entire software project.

Treat this as a pre-release audit of a real product that may be used by real users. Your objective is not merely to find obvious code errors, but to determine whether the product is functional, secure, technically sound, convenient, internally consistent, maintainable, and ready for production.

The prompt is written in English for maximum technical precision. You may perform internal analysis, tool usage, subagent communication, and code investigation in English. However, the final audit report and all user-facing explanations must be written entirely in clear, natural Ukrainian.

Do not modify the project during the initial audit. First complete the investigation and produce the audit report. Do not automatically fix issues unless I explicitly ask you to proceed with implementation after reviewing the report.

# 1. General audit principles

Review the project from scratch.

Do not rely on previous audit results, assumptions, comments, documentation claims, or the apparent intentions of the original developer without verifying them against the actual implementation.

Do not limit yourself to the files that appear important at first glance. Explore the entire repository and identify all relevant application layers, services, packages, configurations, scripts, assets, infrastructure files, and integrations.

Do not report speculative problems as confirmed defects.

Every significant finding must be supported by concrete evidence such as:

* file paths;
* relevant functions, classes, components, routes, schemas, or configuration sections;
* line numbers when available;
* reproduction steps;
* test results;
* browser behavior;
* logs;
* network requests;
* database behavior;
* screenshots or UI observations when supported by available tools;
* an explanation of why the implementation is problematic.

Distinguish clearly between:

* confirmed defect;
* probable defect;
* architectural risk;
* security risk;
* UX problem;
* maintainability issue;
* performance concern;
* accessibility issue;
* improvement opportunity;
* personal design preference.

Do not invent missing functionality. First determine the apparent purpose of the product, its existing scope, and its intended user flows.

# 2. Tools, skills, MCP servers, and subagents

Inspect all tools and capabilities available to you, including:

* repository navigation tools;
* terminal and shell access;
* code search;
* static analysis;
* linters;
* type checking;
* test runners;
* browser automation;
* network inspection;
* database inspection;
* dependency scanners;
* security scanners;
* performance tools;
* accessibility tools;
* MCP servers;
* reusable skills;
* specialized subagents.

Use only tools that materially improve the quality of the audit. Do not run tools merely to appear thorough.

If subagents are supported, act as the lead auditor and delegate independent areas to specialized subagents. Suggested roles include:

1. Architecture Agent
   Reviews system architecture, project structure, module boundaries, dependencies, scalability, coupling, cohesion, and maintainability.

2. Frontend Agent
   Reviews components, state management, routing, forms, client-side logic, loading states, errors, responsiveness, and frontend code quality.

3. Backend Agent
   Reviews APIs, services, controllers, business logic, validation, error handling, integrations, background jobs, and server-side behavior.

4. Database Agent
   Reviews schema design, migrations, constraints, relations, indexing, query safety, data integrity, transactions, and performance.

5. Security Agent
   Reviews authentication, authorization, session management, secrets, API exposure, validation, injection risks, XSS, CSRF, SSRF, insecure direct object references, privilege escalation, rate limiting, data leakage, dependency vulnerabilities, and deployment security.

6. UX/UI Agent
   Reviews usability, navigation, clarity, visual hierarchy, interaction patterns, design consistency, information architecture, user feedback, and product coherence.

7. QA Agent
   Reviews user scenarios, boundary cases, invalid input, failure behavior, regressions, race conditions, empty states, loading states, and test coverage.

8. Performance Agent
   Reviews bundle size, rendering, API latency, caching, database queries, resource loading, memory usage, unnecessary requests, and scalability bottlenecks.

9. Accessibility Agent
   Reviews semantic structure, keyboard navigation, focus management, screen reader support, forms, contrast, labels, ARIA usage, touch targets, and reduced-motion behavior.

Do not create subagents only for quantity. Assign each agent a clear scope, relevant project areas, expected evidence, and required result format.

After receiving subagent findings:

* independently verify important findings against the actual project;
* remove duplicates;
* resolve contradictions;
* reject unsupported claims;
* connect related problems across frontend, backend, database, UX, and security;
* assign final severity and priority;
* consolidate everything into one coherent report.

Do not paste raw subagent conversations into the final result.

# 3. Initial project investigation

Begin by building an accurate mental model of the project.

Investigate:

* the purpose of the product;
* the target users;
* the main use cases;
* the expected user journey;
* the complete technology stack;
* frontend and backend frameworks;
* database technology;
* authentication method;
* external APIs and third-party services;
* deployment and hosting configuration;
* package managers and build systems;
* environment variables;
* application entry points;
* routing structure;
* state management;
* data flow;
* storage mechanisms;
* testing setup;
* monitoring and logging;
* CI/CD configuration;
* documentation.

Inspect the entire repository structure and identify:

* source directories;
* duplicated or legacy implementations;
* dead code;
* unused files;
* abandoned experiments;
* TODO and FIXME comments;
* temporary workarounds;
* commented-out code;
* mock data accidentally used in production paths;
* hardcoded values;
* inconsistent naming;
* obsolete dependencies;
* generated files committed unnecessarily;
* sensitive files that should not be tracked.

Read all relevant documentation, but verify whether the real implementation matches it.

Create a concise project map before beginning the detailed audit.

# 4. Build, run, and test the application

When possible:

* install dependencies safely;
* inspect installation warnings;
* verify lockfiles;
* run the development environment;
* run the production build;
* run existing tests;
* run linting;
* run formatting checks;
* run type checking;
* run static analysis;
* inspect startup logs;
* inspect runtime errors;
* inspect browser console warnings;
* inspect network requests;
* inspect failed requests;
* inspect server logs;
* inspect database migrations;
* inspect application behavior on different routes and screen sizes.

Do not silently change dependency versions or configuration merely to make the project run.

If the project cannot be started, document:

* the exact command used;
* the exact failure;
* the likely cause;
* whether the problem comes from the project, environment, unavailable secrets, missing external services, or incomplete documentation.

Continue with static analysis even if runtime testing is impossible.

# 5. Functional audit

Identify all implemented features and verify whether they actually work.

For every major feature, examine:

* entry point;
* normal user flow;
* successful completion;
* invalid input;
* missing data;
* empty state;
* loading state;
* server failure;
* network timeout;
* authorization failure;
* repeated actions;
* rapid user interaction;
* refresh behavior;
* browser back and forward navigation;
* session expiration;
* duplicate submissions;
* concurrent changes;
* mobile behavior;
* recovery after failure.

Check whether:

* buttons perform the expected action;
* links lead to the correct destination;
* forms validate input correctly;
* validation is implemented on both frontend and backend;
* user data persists correctly;
* destructive actions require appropriate confirmation;
* errors are visible and understandable;
* success states are clearly communicated;
* users can recover from mistakes;
* unfinished functions are visible to users;
* UI controls exist without working logic;
* backend functionality exists but is inaccessible through the UI;
* frontend assumptions disagree with backend behavior;
* duplicated logic produces inconsistent outcomes.

Create a functional inventory containing:

* feature;
* implementation status;
* working status;
* problems found;
* severity;
* affected users;
* recommended action.

# 6. User experience audit

Evaluate the application as a real user, not only as a developer.

Review the complete user journey:

* first visit;
* registration;
* authentication;
* onboarding;
* navigation;
* primary task completion;
* editing existing data;
* searching and filtering;
* error recovery;
* logging out;
* returning later;
* using the application on mobile;
* using the application with slow internet;
* using the application with incomplete or unusual data.

Check whether the interface is:

* understandable without developer knowledge;
* predictable;
* efficient;
* easy to learn;
* resistant to user mistakes;
* consistent across screens;
* clear about the current state;
* clear about what will happen after an action;
* clear about which actions are primary and secondary.

Look for:

* confusing labels;
* ambiguous icons;
* hidden functionality;
* excessive numbers of clicks;
* unnecessary steps;
* poor grouping;
* unclear hierarchy;
* inconsistent terminology;
* missing feedback;
* unexpected navigation;
* forms that reset data;
* poor defaults;
* unclear validation messages;
* weak empty states;
* weak onboarding;
* poor confirmation flows;
* modals that are difficult to close;
* inaccessible actions;
* information overload;
* features located in unintuitive places;
* actions that behave differently on different screens;
* cases where the UI technically works but feels inconvenient.

Do not assess UX only by appearance. Analyze whether interaction logic and behavior are consistent.

# 7. UI and design-system audit

Determine whether the product follows a coherent visual and interaction system.

Review:

* layout;
* spacing;
* typography;
* visual hierarchy;
* component sizing;
* alignment;
* colors;
* borders;
* shadows;
* icons;
* buttons;
* inputs;
* cards;
* tables;
* menus;
* dialogs;
* notifications;
* loading indicators;
* empty states;
* error states;
* responsive behavior;
* animations;
* transitions;
* hover, focus, active, selected, disabled, loading, and destructive states.

Check consistency not only in colors, but also in functionality and behavior.

For example:

* Do visually identical buttons behave identically?
* Do primary actions always look like primary actions?
* Are destructive actions presented consistently?
* Are similar forms structured in the same way?
* Do menus open and close consistently?
* Do dialogs use the same interaction model?
* Are validation messages displayed in the same location and style?
* Do repeated components support the same keyboard behavior?
* Are similar data states represented consistently?
* Are the same terms used for the same concepts?
* Are users forced to relearn interaction patterns on different pages?

Identify one-off components that should be reusable design-system components.

Check whether styling logic is:

* duplicated;
* fragmented;
* over-specific;
* difficult to maintain;
* dependent on magic numbers;
* inconsistent across breakpoints;
* mixing several visual systems.

Evaluate whether all screens look and behave like parts of one product.

# 8. Responsive and cross-device audit

Test or inspect the interface at multiple viewport sizes, including approximately:

* small mobile;
* large mobile;
* tablet;
* laptop;
* desktop;
* wide desktop.

Check:

* overflow;
* clipped content;
* unreadable text;
* broken grids;
* fixed-width elements;
* overlapping controls;
* unusable menus;
* forms that do not fit;
* tables on mobile;
* dialogs exceeding viewport size;
* poor touch targets;
* layout shifts;
* sticky elements hiding content;
* keyboard opening behavior on mobile;
* orientation changes;
* long text;
* localization expansion;
* empty and very large datasets.

Report exact pages and components where responsive behavior fails.

# 9. Accessibility audit

Assess compliance with modern accessibility practices and WCAG principles where applicable.

Review:

* semantic HTML;
* heading hierarchy;
* landmarks;
* keyboard navigation;
* tab order;
* focus visibility;
* focus trapping in dialogs;
* focus restoration;
* accessible names;
* labels for form controls;
* error associations;
* ARIA attributes;
* live regions;
* screen reader announcements;
* image alt text;
* icon-only controls;
* color contrast;
* reliance on color alone;
* disabled controls;
* touch target sizes;
* zoom behavior;
* reduced motion;
* skip navigation;
* table semantics;
* language declaration.

Identify both technical violations and practical usability barriers.

# 10. Frontend code audit

Review:

* component architecture;
* separation of concerns;
* state ownership;
* local versus global state;
* derived state;
* lifecycle handling;
* asynchronous logic;
* race conditions;
* stale state;
* duplicated requests;
* unnecessary re-renders;
* event listener cleanup;
* memory leaks;
* form architecture;
* validation;
* routing;
* protected routes;
* error boundaries;
* loading boundaries;
* caching;
* API client structure;
* type safety;
* reusable components;
* hook usage;
* side effects;
* dependency arrays;
* direct DOM manipulation;
* storage usage;
* handling of tokens and user data;
* dependency quality.

Look for code that currently works but is fragile, difficult to extend, or likely to cause regressions.

# 11. Backend and API audit

Review:

* route structure;
* controller design;
* service boundaries;
* business logic;
* input validation;
* output validation;
* error handling;
* HTTP status codes;
* authentication;
* authorization;
* ownership checks;
* pagination;
* filtering;
* sorting;
* rate limiting;
* idempotency;
* retries;
* timeouts;
* logging;
* transactions;
* background operations;
* API versioning;
* file uploads;
* external API calls;
* data serialization;
* information exposure;
* concurrency behavior.

Check whether clients can:

* access another user’s resources;
* change protected fields;
* bypass frontend validation;
* submit unexpected data types;
* send extremely large payloads;
* repeat sensitive actions;
* enumerate users or records;
* trigger inconsistent database state;
* receive stack traces or sensitive internal details.

Verify that status codes and error response formats are consistent.

# 12. Database and data-integrity audit

Review:

* schemas;
* migrations;
* primary keys;
* foreign keys;
* unique constraints;
* nullability;
* default values;
* indexes;
* timestamps;
* deletion strategy;
* cascading behavior;
* transactions;
* normalization;
* denormalization;
* query patterns;
* pagination;
* sorting;
* data ownership;
* backups and recovery assumptions;
* sensitive data storage.

Look for:

* missing constraints;
* duplicate records;
* orphaned records;
* race conditions;
* N+1 queries;
* full table scans;
* unsafe dynamic queries;
* incorrect data types;
* inconsistent time zones;
* incorrect monetary calculations;
* floating-point problems;
* missing transaction boundaries;
* destructive migrations;
* migrations that cannot be safely rolled back;
* application logic compensating for weak schema design.

# 13. Security audit

Perform a serious security review based on the actual project architecture.

Review at minimum:

* authentication;
* authorization;
* role and permission checks;
* resource ownership checks;
* session handling;
* token storage;
* password handling;
* password reset flows;
* email verification;
* secrets management;
* environment variables;
* API keys;
* CORS;
* CSP;
* cookies;
* CSRF protection;
* XSS;
* SQL injection;
* NoSQL injection;
* command injection;
* template injection;
* path traversal;
* file uploads;
* SSRF;
* open redirects;
* insecure deserialization;
* prototype pollution;
* mass assignment;
* IDOR;
* privilege escalation;
* brute-force protection;
* rate limiting;
* account enumeration;
* sensitive data exposure;
* debug endpoints;
* verbose errors;
* logging of secrets or personal data;
* dependency vulnerabilities;
* supply-chain risks;
* insecure deployment defaults.

Do not claim a vulnerability solely because a generic protection is absent. Evaluate whether the vulnerability is actually applicable to this architecture.

For each security finding provide:

* title;
* severity;
* confidence;
* affected component;
* attack preconditions;
* realistic attack scenario;
* technical evidence;
* potential impact;
* remediation;
* verification method after remediation.

Never expose real secrets in the report. Redact sensitive values.

# 14. Performance audit

Review frontend, backend, database, and infrastructure performance.

Frontend:

* initial bundle size;
* code splitting;
* lazy loading;
* render frequency;
* expensive calculations;
* large lists;
* image optimization;
* font loading;
* duplicated requests;
* caching;
* layout shifts;
* blocking resources;
* hydration problems where applicable.

Backend:

* slow endpoints;
* blocking operations;
* sequential operations that could be parallelized safely;
* missing caching;
* repeated database access;
* expensive serialization;
* large response payloads;
* connection handling;
* timeouts;
* retries;
* memory growth;
* CPU-intensive operations.

Database:

* missing indexes;
* inefficient joins;
* N+1 queries;
* unbounded queries;
* expensive sorting;
* lack of pagination;
* poor transaction design;
* unnecessary writes.

Separate measured problems from theoretical scalability concerns.

# 15. Architecture and maintainability audit

Assess:

* module boundaries;
* separation of concerns;
* dependency direction;
* coupling;
* cohesion;
* duplication;
* abstractions;
* naming;
* code organization;
* configuration management;
* extensibility;
* testability;
* observability;
* deployment portability;
* onboarding difficulty;
* documentation quality.

Identify:

* god components;
* god services;
* circular dependencies;
* business logic inside UI components;
* database logic mixed with transport logic;
* repeated validation;
* duplicated constants;
* hidden global state;
* feature coupling;
* fragile abstractions;
* unnecessary abstractions;
* premature complexity;
* inconsistent architectural patterns.

Do not automatically recommend a complete rewrite. Prefer incremental improvements unless the current architecture makes safe development impractical.

# 16. Dependencies and configuration audit

Inspect:

* package manifests;
* lockfiles;
* dependency versions;
* deprecated packages;
* duplicate packages;
* unused dependencies;
* vulnerable dependencies;
* unnecessary runtime dependencies;
* build configuration;
* environment configuration;
* development versus production settings;
* secret handling;
* Docker files;
* reverse proxy settings;
* CI/CD;
* caching headers;
* compression;
* source maps;
* logging configuration;
* health checks;
* database connection settings.

Check whether a clean installation and production build are reproducible.

# 17. Testing and quality assurance audit

Review existing tests:

* unit tests;
* integration tests;
* end-to-end tests;
* API tests;
* component tests;
* security tests;
* regression tests.

Determine:

* what is covered;
* what is not covered;
* whether tests assert meaningful behavior;
* whether tests are flaky;
* whether mocks hide real integration problems;
* whether critical flows have end-to-end coverage;
* whether tests can run in CI;
* whether test data is isolated;
* whether failures are easy to diagnose.

Recommend a prioritized testing strategy. Do not simply suggest “increase coverage.” Specify which flows need which type of test.

# 18. Product improvement analysis

After identifying defects, think beyond bug fixing.

Suggest improvements related to:

* user experience;
* onboarding;
* navigation;
* feature discoverability;
* workflow efficiency;
* design consistency;
* automation;
* error prevention;
* useful defaults;
* feedback;
* accessibility;
* performance;
* maintainability;
* security;
* product differentiation.

Separate recommendations into:

1. Required fixes
   Problems that should be corrected before release.

2. High-value improvements
   Changes with a strong positive effect on users or development quality.

3. Optional enhancements
   Useful ideas that are not currently necessary.

4. Future product ideas
   New capabilities that fit the project’s existing purpose.

Do not propose features that would unnecessarily complicate the product or conflict with its apparent purpose.

For every major idea explain:

* what problem it solves;
* who benefits;
* expected value;
* approximate implementation complexity;
* dependencies;
* risks;
* whether it should be done now or later.

# 19. Severity and priority system

Use the following severity levels:

* Critical — immediate security, data-loss, privacy, or complete product failure risk.
* High — major feature failure, serious security weakness, major UX blocker, or substantial production risk.
* Medium — meaningful defect or architectural problem that affects reliability, usability, maintainability, or performance.
* Low — limited-impact defect, inconsistency, minor accessibility issue, or localized maintainability concern.
* Improvement — not a defect, but a justified opportunity to improve the product.

Also assign implementation priority:

* P0 — must be addressed immediately;
* P1 — should be addressed before release;
* P2 — should be addressed soon after critical work;
* P3 — can be planned for a later iteration.

Do not inflate severity. Explain why each issue received its rating.

# 20. Required final report structure

The final report must be written entirely in Ukrainian.

Keep technical identifiers such as file paths, variable names, function names, class names, API routes, database fields, commands, error messages, and configuration keys in their original form.

English technical terms may be included in parentheses where this improves accuracy, but all explanations must remain understandable in Ukrainian.

Use the following report structure:

## 1. Резюме аудиту

Include:

* overall project condition;
* apparent product purpose;
* release readiness;
* strongest areas;
* weakest areas;
* number of findings by severity;
* main production risks;
* final recommendation.

Provide a clear verdict such as:

* ready for production;
* ready after minor fixes;
* requires significant work before release;
* not ready for production.

## 2. Карта проєкту

Describe:

* architecture;
* technologies;
* main modules;
* frontend;
* backend;
* database;
* external services;
* authentication;
* deployment;
* important data flows.

## 3. Що було перевірено

List:

* files and modules investigated;
* commands executed;
* tests executed;
* tools used;
* runtime flows checked;
* limitations of the audit.

## 4. Критичні та високопріоритетні проблеми

For each finding include:

* ID;
* title;
* severity;
* priority;
* confidence;
* category;
* affected files or components;
* evidence;
* reproduction steps where applicable;
* user impact;
* technical impact;
* root cause;
* recommended remediation;
* remediation complexity;
* verification method.

## 5. Повний реєстр проблем

Provide a structured table containing:

* ID;
* category;
* title;
* severity;
* priority;
* affected area;
* short recommendation.

## 6. Функціональний аудит

Describe every major feature and whether it works correctly.

## 7. UX-аудит

Describe usability problems, inconsistent behavior, confusing flows, and missing feedback.

## 8. UI та дизайн-система

Describe visual, component, interaction, and responsive inconsistencies.

## 9. Аудит доступності

Describe accessibility findings and affected users.

## 10. Аудит frontend

Describe frontend architecture, state, components, forms, routing, API usage, and code-quality findings.

## 11. Аудит backend та API

Describe backend logic, validation, errors, authorization, integrations, and API consistency.

## 12. Аудит бази даних

Describe data integrity, schema, migrations, constraints, indexes, queries, and transaction findings.

## 13. Аудит безпеки

Describe confirmed risks, realistic attack scenarios, impact, and remediation.

## 14. Аудит продуктивності

Separate measured bottlenecks from potential future risks.

## 15. Архітектура та підтримуваність

Describe structural weaknesses, technical debt, duplication, and maintainability risks.

## 16. Тестування

Describe current test quality, missing coverage, and a prioritized test strategy.

## 17. Пропозиції щодо покращення продукту

Separate:

* required fixes;
* high-value improvements;
* optional enhancements;
* future ideas.

## 18. Пріоритетний план робіт

Create a phased implementation roadmap:

### Етап 0 — негайні дії

Critical security, data-loss, and blocking issues.

### Етап 1 — підготовка до релізу

High-severity bugs and essential UX fixes.

### Етап 2 — стабілізація

Architecture, testing, performance, and maintainability improvements.

### Етап 3 — розвиток продукту

Optional UX and product improvements.

For each phase include:

* tasks;
* dependencies;
* expected result;
* approximate complexity;
* risks.

## 19. Швидкі покращення

List low-effort, high-value improvements that can be implemented quickly.

## 20. Підсумковий вердикт

Conclude with:

* whether the product is ready for real users;
* what absolutely must be fixed first;
* the largest security risk;
* the largest functional risk;
* the largest UX problem;
* the most valuable improvement;
* the recommended next action.

# 21. Audit quality requirements

The final report must:

* be specific to this project;
* avoid generic checklist language;
* cite concrete project evidence;
* distinguish facts from assumptions;
* explain uncertainty;
* avoid duplicate findings;
* connect related issues;
* prioritize by real impact;
* include actionable recommendations;
* avoid unnecessary rewrites;
* avoid overwhelming the report with trivial style preferences.

Do not stop after discovering the first set of problems. Continue until all major project areas have been investigated.

Do not provide the final report until all relevant subagent findings have been consolidated, deduplicated, independently verified, prioritized, and translated into Ukrainian.

Begin by inspecting the project structure, available tools, project documentation, and execution commands. Then create an internal audit plan and proceed with the full investigation.
