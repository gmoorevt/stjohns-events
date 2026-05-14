"""add user status for approval queue

Revision ID: ab17aabe3783
Revises: 3eca2e54e0c7
Create Date: 2026-05-14 10:47:43.048462

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'ab17aabe3783'
down_revision: Union[str, None] = '3eca2e54e0c7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(sa.Column('status', sa.String(length=16), nullable=False, server_default='approved'))
    # Drop the server_default so future inserts use the application-side default ('pending').
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.alter_column('status', server_default=None)


def downgrade() -> None:
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('status')
