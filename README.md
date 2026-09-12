# Dami

A lightweight, policy-oriented ORM for Ruby on SQLite. One gem, no framework required.

- **Four-pillar DSL** — structure (`Dami.model`), write rules (`Dami.behavior`), queries (`Dami.scopes`), presentation (`Dami.present`). Put something in the wrong block and Dami tells you where it goes.
- **Hardened writes by default** — unknown fields raise, protected fields need an explicit `permit:`, every value is bound (never interpolated).
- **Real constraints** — `null:`, `unique:`, `default:`, `references:` in migrations; foreign keys are enforced; violations come back as `Dami::NotNullViolation`, `Dami::UniqueConstraintViolation`, `Dami::ForeignKeyViolation`.
- **Flows** — multi-step business operations that run in one transaction, roll back on failure, and fire side effects only after the commit.
- **Small and fast** — a connection pool, WAL, prepared-statement cache, and nothing you didn't ask for.

## Install

```ruby
# Gemfile
gem "dami"
```

## Five-minute tour

```ruby
require "dami"

Dami.connect(:default, adapter: :sqlite, path: "app.db")

# Schema (or write a migration — see docs/09.Migrations.md)
Dami::Migration.new(Dami.database).create_table(:users) do |t|
  t.field :id, :primary_key
  t.field :email, :string, null: false, unique: true
  t.field :name, :string, null: false
  t.field :role, :string, default: "member"
  t.timestamps
end

# Structure
Dami.model :users do
  fields do
    field :email, :string
    field :name, :string
    field :role, :string
    field :created_at, :datetime
    field :updated_at, :datetime
  end
end

# Write-side rules
Dami.behavior :users do
  validate do
    rule :email, :required, :email
    rule :name, :required
  end
  protection { protect :role }
end

# Collection queries
Dami.scopes :users do
  scope :admins, -> { where(role: "admin") }
end

user = Dami.db(:users).create(email: "ana@example.com", name: "Ana")
user[:id]          # => 1
user.name          # => "Ana"
user[:created_at]  # => "2026-09-12 18:40:00" (UTC)

Dami.db(:users).where(id: user[:id]).update(name: "Ana G.")
Dami.db(:users).admins.count                 # => 0
Dami.db(:users).where(role: "admin").to_a    # => []

Dami.db(:users).create(email: "not-an-email", name: "")
# => Dami::ValidationError, errors: { email: ["must be valid email"], name: ["is required"] }

Dami.db(:users).where(id: 1).update(role: "admin")
# => Dami::ProtectionError (protected field) — pass permit: [:role] where you mean it
```

## Documentation

Everything is in [`docs/`](docs/), in reading order:

1. [Getting Started](docs/01.Getting_Started.md)
2. [Models and Fields](docs/02.Models_and_Fields.md)
3. [Querying](docs/03.Querying.md)
4. [Creating, Updating, Deleting](docs/04.Creating_Updating_Deleting.md)
5. [Validation](docs/05.Validation.md)
6. [Protection](docs/06.Protection.md)
7. [Associations](docs/07.Associations.md)
8. [Scopes](docs/08.Scopes.md)
9. [Migrations](docs/09.Migrations.md)
10. [Flows and Commands](docs/10.Flows_and_Commands.md)
11. [Localization](docs/11.Localization.md)
12. [The Dami Way](docs/12.TheDamiWay.md)

## Scope

SQLite only, on purpose. If you need PostgreSQL or MySQL today, Dami is not the right tool yet.

## Development

```
bundle install
rake test        # ruby test/run_all.rb
rake build       # gem build dami.gemspec
```

## License

MIT — see [LICENSE](LICENSE).
