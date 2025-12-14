# Import all the models, so that Base has them before being
# imported by Alembic
from app.db.base_class import Base  # noqa
from app.models.user import User  # noqa
from app.models.track import Track  # noqa
from app.models.playlist import Playlist  # noqa
from app.models.run import Run, RunTrack  # noqa
