from pathlib import Path


def test_system_prompt_requires_semantic_skill_selection() -> None:
    repo_root = Path(__file__).resolve().parents[2]
    zh_prompt = (repo_root / "docs" / "ling_system_prompt.md").read_text(
        encoding="utf-8"
    )
    en_prompt = (repo_root / "docs" / "ling_system_prompt_en.md").read_text(
        encoding="utf-8"
    )

    assert "不按关键词、入口、按钮或单个名词机械匹配" in zh_prompt
    assert "即使用户没有显式写出内部 skill 标签" in zh_prompt
    assert "主任务是行程规划，应先加载行程规划能力" in zh_prompt
    assert "do not mechanically match by keywords" in en_prompt
    assert "does not include an internal skill tag" in en_prompt
    assert "the main task is trip planning" in en_prompt


def test_trip_planning_skill_forbids_guessing_missing_constraints() -> None:
    repo_root = Path(__file__).resolve().parents[2]
    skill = (repo_root / "skills" / "trip-planning" / "SKILL.md").read_text(
        encoding="utf-8"
    )

    assert "不要把用户没给出的约束当事实" in skill
    assert "这些假设必须写在方案前" in skill
    assert "不生成看似确定的完整行程" in skill

