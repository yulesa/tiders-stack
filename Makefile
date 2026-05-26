# Root Makefile — orchestrates per-project pipelines.
# Each project under projects/<name>.mk must define <name>-ingest and <name>-dbt targets.

PROJECTS := aave_v4 uniswap_v3

INGEST_TARGETS    := $(addsuffix -ingest,$(PROJECTS))
DBT_TARGETS       := $(addsuffix -dbt,$(PROJECTS))
DASHBOARD_TARGETS := $(addsuffix -dashboard,$(PROJECTS))

.PHONY: all ingest dbt dashboard $(PROJECTS) $(INGEST_TARGETS) $(DBT_TARGETS) $(DASHBOARD_TARGETS)

include $(addprefix projects/,$(addsuffix .mk,$(PROJECTS)))

# Full pipeline per project: <project> depends on <project>-ingest + <project>-dbt + <project>-dashboard
$(PROJECTS): %: %-ingest %-dbt %-dashboard

# Stage targets across all projects
ingest:    $(INGEST_TARGETS)
dbt:       $(DBT_TARGETS)
dashboard: $(DASHBOARD_TARGETS)

all: $(PROJECTS)
