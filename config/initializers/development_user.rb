# frozen_string_literal: true

DEVELOPMENT_ADMIN_USER_CONFIG = {
  uid: 'admin',
  email: 'development@example.com',
  password: 'development',
  is_admin: true
}.freeze

DEVELOPMENT_NON_ADMIN_USER_CONFIG = {
  uid: 'user',
  email: 'user@example.com',
  password: 'user-password',
  is_admin: false
}.freeze
