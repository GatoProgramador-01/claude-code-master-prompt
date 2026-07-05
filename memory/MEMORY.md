# Memory Index

- [User Profile](user_profile.md) — Full stack dev evolving toward Tech Lead + DevOps, studying AWS multi-agent architecture
- [HCL / Terraform Bugs](feedback_hcl_terraform.md) — lifecycle placement, no commas in blocks, archive_file vs filebase64sha256
- [Python Testing Isolation](feedback_python_testing.md) — unique class names, no __init__.py in tests/, sys.modules before exec_module, guard tests
- [GitHub Actions Bugs](feedback_github_actions.md) — verify branch name, mapfile vs pipe-while subshell bug
- [multiagent-aws-infra project](project_multiagent_aws_infra.md) — 4 semanas completas, 56 tests, stack Layer1-2-3, próximos pasos
- [medium-agent-factory project](project_medium_agent_factory.md) — LangGraph multi-agent pipeline, all 4 LLMOps weeks done, CI/CD wired, deploy TODO pending real tokens
- [medium-agent-factory deploy TODO](project_medium_factory_deploy_todo.md) — step-by-step Railway + Vercel + MongoDB Atlas deploy checklist
- [LLMOps Production Study](reference_llmops_study.md) — eval-in-CI (deepeval/RAGAS/LangSmith), model serving (Ollama/vLLM/TGI), Langfuse observability, prompt versioning, local prod Docker stack, interview narrative
- [Learning Style](feedback_learning_style.md) — learns by reading full code examples in VS Code; always teach with complete runnable code, never prose-only
- [LLM JSON Coerce Fix](feedback_llm_json_coerce.md) — LLMs emit curly quotes/em-dashes that break json.loads; always use unicode-normalizer fallback in every Pydantic str→list validator
- [setuptools Package Discovery](feedback_setuptools_package_discovery.md) — evals/ or scripts/ next to app/ causes "Multiple top-level packages" error; always add [tool.setuptools.packages.find] include=["app*"]
- [Master Prompt Repo](reference_master_prompt_repo.md) — CLAUDE.md versioned at Documents/github/claude-code-master-prompt (public repo, branch main)
- [SDD Mandatory Every Sprint](feedback_sdd_mandatory.md) — subagent-driven-development is non-negotiable after writing-plans; parallel is the default, never optional
