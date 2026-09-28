"""Skill wiring: local custom skills plus the managed GCP Skill Registry,
grouped into a single SkillToolset for the agent."""

import os
import pathlib

from google.adk.integrations.skill_registry import GCPSkillRegistry
from google.adk.skills import load_skill_from_dir
from google.adk.tools.skill_toolset import SkillToolset

MANAGED_SKILL_NAME = "bigquery-basics"
CUSTOM_SKILL_DIR = pathlib.Path(__file__).parent / "skills" / "custom-sql-guidelines"


def build_skill_toolset() -> SkillToolset:
    custom_skill = load_skill_from_dir(CUSTOM_SKILL_DIR)

    skill_registry = GCPSkillRegistry(
        project_id=os.environ.get("GOOGLE_CLOUD_PROJECT", "my-project"),
        location=os.environ.get("GOOGLE_CLOUD_SKILL_LOCATION", "us"),
    )

    return SkillToolset(
        skills=[custom_skill],
        registry=skill_registry,
    )
