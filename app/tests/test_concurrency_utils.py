import unittest

from utils.concurrency import run_with_concurrency_limit_ordered


class ConcurrencyUtilsTests(unittest.IsolatedAsyncioTestCase):
    async def test_return_exceptions_preserves_result_order(self) -> None:
        error = RuntimeError("boom")

        async def first() -> str:
            return "first"

        async def second() -> str:
            raise error

        async def third() -> str:
            return "third"

        results = await run_with_concurrency_limit_ordered(
            3,
            [first, second, third],
            return_exceptions=True,
        )

        self.assertEqual(results[0], "first")
        self.assertIs(results[1], error)
        self.assertEqual(results[2], "third")
