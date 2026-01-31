"""Add email auth fields and avg_cadence

Revision ID: add_email_auth_cadence
Revises: 564a3cbdfb96
Create Date: 2026-01-28

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'add_email_auth_cadence'
down_revision: Union[str, None] = '564a3cbdfb96'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add new columns to users table for email authentication
    op.add_column('users', sa.Column('hashed_password', sa.String(), nullable=True))
    op.add_column('users', sa.Column('first_name', sa.String(), nullable=True))
    op.add_column('users', sa.Column('last_name', sa.String(), nullable=True))
    
    # Make apple_user_id nullable (for email-only users)
    op.alter_column('users', 'apple_user_id',
                    existing_type=sa.String(),
                    nullable=True)
    
    # Add unique index on email for faster lookups and uniqueness constraint
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    
    # Add avg_cadence to runs table
    op.add_column('runs', sa.Column('avg_cadence', sa.Integer(), nullable=True))


def downgrade() -> None:
    # Remove avg_cadence from runs
    op.drop_column('runs', 'avg_cadence')
    
    # Remove email index
    op.drop_index(op.f('ix_users_email'), table_name='users')
    
    # Make apple_user_id required again
    op.alter_column('users', 'apple_user_id',
                    existing_type=sa.String(),
                    nullable=False)
    
    # Remove new user columns
    op.drop_column('users', 'last_name')
    op.drop_column('users', 'first_name')
    op.drop_column('users', 'hashed_password')
