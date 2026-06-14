"""API router package."""

__all__ = ["router"]


def __getattr__(name: str):
    if name == "router":
        from api.router import router

        return router
    raise AttributeError(name)
