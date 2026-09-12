# **The Dami Manifesto: Architecture You Can't Break**

## The Problem Every Rails Developer Knows

Open any Rails codebase that's been in production for more than a year. You'll find the same problems:

**The 2,000-line `User` model** that handles everything from database schema to email formatting to birthday notifications. It started clean. It decayed slowly. Now nobody wants to touch it.

**The callback chain of death.** A simple `user.save` triggers 47 invisible operations. When one fails, you spend days debugging why users got created but welcome emails didn't send.

**The copy-paste validation epidemic.** That phone number regex exists in 30 models. You need to update it. Good luck.

**The scattered YAML translation files.** Validation messages in one file, model names in another, error messages somewhere else. Keeping them synchronized is a nightmare.

These aren't failures of discipline. **They're failures of tooling.**

Rails doesn't prevent bad architecture—it just makes it easy to write. The result is technical debt that compounds daily until your codebase becomes unmaintainable.

**Dami solves this. Permanently.**

---

## The Solution: Six Architectural Guarantees

Dami isn't trying to be everything to everyone. It's a precision tool that solves the hardest problems in application architecture.

### **1. Enforced Separation: Fat Models Are Impossible**

Most frameworks suggest good architecture. Dami **enforces** it.

The Four Pillars separate concerns at the DSL level:
- `Dami.model` - Structure only
- `Dami.behavior` - Write-side rules only  
- `Dami.scopes` - Query logic only
- `Dami.flow` - Business workflows

Try to put a validation in your model? **The framework stops you:**

```ruby
Dami.model :users do
  validate { rule :email, :required }
end

# => Dami::InvalidDSLError: 'validate' not allowed here.
#    Define it in a Dami.behavior block.
```

**This isn't a suggestion. It's a compile-time guarantee.** Your architecture can't decay because the framework won't let it.

---

### **2. Validation as Infrastructure**

Stop copy-pasting validation logic across models. Dami treats validations as reusable components:

```ruby
# Define once
Dami.rules :default, {
  phone: { check: /\A\d{3}-\d{3}-\d{4}\z/, message: "Invalid format" }
}

# Use everywhere
Dami.behavior(:users) { validate { rule :phone, :phone } }
Dami.behavior(:contacts) { validate { rule :mobile, :phone } }
Dami.behavior(:vendors) { validate { rule :support_line, :phone } }
```

**Update once. Updates everywhere.** Perfect consistency across your entire application.

---

### **3. I18n as Core Infrastructure**

Rails bolts on internationalization as an afterthought. Dami builds it in as **first-class infrastructure.**

One DSL for all user-facing text:

```ruby
Dami.localize :validations do
  en { set :required, "cannot be blank" }
  es { set :required, "no puede estar en blanco" }
  fr { set :required, "ne peut pas être vide" }
end
```

**Auto-detection included.** Using Rails or Sinatra with the i18n gem? Dami automatically uses `I18n.locale`. Zero configuration.

Four translation scopes cover everything:
- `:validations` - Error messages
- `:models` - Attribute names for forms
- `:enums` - Display values
- `:errors` - System exceptions

**One source of truth. Any language. Zero overhead.**

---

### **4. Migrations From Intent**

Stop writing migration files. Describe what you want. Dami generates the how.

**Define the model:**
```ruby
Dami.model :users do
  fields { field :name, :string }
end
```

**Generate the migration:**
```bash
$ dami generate migration CreateUsers
✅ Migration created: db/migrations/20251018_create_users.rb
```

**Add a field:**
```ruby
Dami.model :users do
  fields do
    field :name, :string
    field :status, :string  # New
  end
end
```

**Generate again:**
```bash
$ dami generate migration AddStatusToUsers
✅ Migration created!
```

Dami compares model to schema. Writes perfect, reversible migrations. **The tedium is eliminated.**

---

### **5. Transactional Workflows**

Rails callbacks scatter logic across time and space. Dami makes business logic **explicit and atomic:**

```ruby
Dami.flow :user_onboarding do |params|
  step :create_user { db[:users].create(params) }
  step :send_email { Mailer.welcome(user) }
  step :track_event { Analytics.track('signup') }
  step :sync_crm { CRM.sync(user) }
end
```

**If any step fails, everything rolls back.** Your database stays consistent. No orphaned records. No mystery states.

**The Dami Guarantee:** Atomic workflows or nothing.

---

### **6. Performance by Design**

Most ORMs optimize later. Dami benchmarked from line one:

```
ActiveRecord (includes): 847ms
Dami (preload):          524ms  ← 1.6x faster

ActiveRecord (count):    234ms  
Dami (count):            207ms  ← Actual SQL COUNT(*)

ActiveRecord (create):   892ms
Dami (create):           743ms  ← No object overhead
```

**These are real benchmarks. Public. Reproducible.**

When you eliminate unnecessary abstractions, performance comes free.

---

## When Dami Fits

**Perfect for:**
- Mid-size applications (10K-1M records)
- International SaaS products
- Teams that value architecture over feature bloat
- Developers tired of fighting their tools

**Not perfect for:**
- Enterprise applications needing PostgreSQL today (coming v1.1)
- Projects requiring Rails' massive gem ecosystem immediately
- Facebook-scale requirements
- Full-stack framework needs (Dami is ORM + business logic only)

**Dami is a scalpel, not a Swiss Army knife.** For the right job, it's the best tool in Ruby.

---

## The Architectural Philosophy

Most frameworks try to be flexible. Dami believes **constraints liberate creativity.**

When you can't put code in the wrong place, you stop wasting mental energy on "where does this go?" When validations are infrastructure, consistency is automatic. When business logic is explicit, debugging is straightforward.

**Dami doesn't just solve today's problems. It prevents tomorrow's.**

The framework that guides you toward better code. The ORM that makes architectural decay impossible. The tool that actually sparks joy.

---

## Production Ready

- ✅ **228 comprehensive tests** - Edge cases, concurrency, unicode, NULL handling
- ✅ **Zero dependencies** - Just SQLite gem
- ✅ **Battle-tested** - Stress-tested with concurrent operations
- ✅ **MIT License** - Use it anywhere
- ✅ **v1.0** - Production stable

---

## Get Started

```bash
gem install dami
```

**The Ruby ORM that prevents bad architecture by design.**

**Dami. Build better.**

---

*Production Ready v1.0 • MIT License • Made for Developers Who Ship*

---

# **Website Structure (Revised)**

## **Homepage**

### **Hero Section**
**H1:** The Ruby ORM That Prevents Bad Architecture  
**Subheadline:** Enforced separation. Built-in i18n. Atomic workflows. Zero compromise.  
**CTA:** `gem install dami`  
**Secondary CTA:** See How It Works →

**Hero Visual:** Split screen showing a bloated Rails model transforming into clean Four Pillars code

---

### **Problem Section**
**H2:** You've Felt This Pain

**Three columns:**

**1. Fat Models**  
Your `User` class is 2,000 lines. Schema, validations, callbacks, formatters—all tangled together.

**2. Callback Hell**  
User saved but email didn't send. Good luck debugging 47 invisible callbacks.

**3. Copy-Paste Validations**  
That regex is in 30 models. Need to change it? Better hope you find them all.

---

### **Solution Section**
**H2:** Dami Solves This. Permanently.

**Three-column features:**

**1. Enforced Architecture**  
**Badge:** Impossible to Break  
Four Pillars separate concerns at the DSL level. Try to mix them? The framework stops you.

**2. Validation Registry**  
**Badge:** Define Once  
Register rules globally. Use them everywhere. Update in one place.

**3. Native I18n**  
**Badge:** Built-In  
One DSL for all translations. Auto-detects locale. Zero overhead.

**CTA:** Explore the Architecture →

---

### **Code Comparison Section**
**H2:** Before & After

**Split screen:**

**Left - Rails:**
```ruby
class User < ApplicationRecord
  validates :email, format: { with: /.../ }
  validates :phone, format: { with: /.../ }
  after_create :send_email
  after_create :track_event
  # 1,947 more lines...
  
  def full_name
    "#{first_name} #{last_name}"
  end
end
```

**Right - Dami:**
```ruby
# Structure
Dami.model :users do
  fields { field :email, :string }
end

# Behavior
Dami.behavior :users do
  validate do
    rule :email, :email
    rule :phone, :phone
  end
end

# Flow
Dami.flow :signup do |params|
  step(:create) { db[:users].create(params) }
  step(:email) { Mailer.welcome(user) }
  step(:track) { Analytics.track('signup') }
end
```

**Callout:** Clean. Testable. Maintainable.

---

### **Six Guarantees Section**
**H2:** Six Architectural Guarantees

**Grid layout (2x3):**

1. **🏗️ Enforced Pillars**  
   Framework prevents mixing concerns

2. **🔐 Central Validation**  
   Define once, use everywhere

3. **🌍 Native I18n**  
   Built-in, not bolted on

4. **✨ Auto Migrations**  
   Generate from models, not hand-write

5. **🔄 Atomic Flows**  
   Transactional workflows, not callbacks

6. **⚡ Proven Speed**  
   1.6x faster, benchmarked, reproducible

---

### **Migration Magic Section**
**H2:** Migrations Without the Tedium

**Interactive demo:**

**Step 1:** Define model  
**Step 2:** Run `dami generate migration`  
**Step 3:** Perfect migration appears

**Animation:** Typing field into model → migration file generates automatically

**Callout:** Never write a migration by hand again.

---

### **I18n Spotlight**
**H2:** Built for the Global Web

**Live locale switcher demo:**

```ruby
Dami.db(:users).create(email: '')
```

**Error output changes with locale:**
- 🇬🇧 "Email cannot be blank"
- 🇪🇸 "Email no puede estar en blanco"  
- 🇫🇷 "Email ne peut pas être vide"

**Four translation scopes:**
- Validations
- Model names
- Enum values
- Error messages

**Callout:** One codebase. Every language. Zero friction.

---

### **Performance Section**
**H2:** Speed You Can Prove

**Benchmark graph:**
```
Association Preloading:
ActiveRecord: ████████████████ 847ms
Dami:         █████████ 524ms  ← 1.6x faster
```

**CTA:** Run the Benchmarks Yourself →

---

### **When It Fits Section**
**H2:** Built For

**Grid:**
- 📊 Mid-size applications (10K-1M records)
- 🌍 International SaaS products
- 🏗️ Teams valuing architecture
- ⚡ Developers who ship

**Not Built For:**
- Enterprise apps needing PostgreSQL today
- Projects requiring massive gem ecosystems
- Facebook-scale requirements

**Callout:** Honest about what it is. Confident in what it does.

---

### **Social Proof**
**H2:** Developers Who Switched

**Three testimonial cards:**

1. "Finally, an ORM that prevents fat models instead of just warning about them."
2. "The validation registry alone is worth switching. Never copy-pasting again."
3. "Built-in i18n that actually works. This should be standard."

---

### **Final CTA**
**H2:** Build Better

```bash
gem install dami
```

**Sub-CTA:**
- Read the Docs →
- View on GitHub →
- Join Discord →

**Badge:** v1.0 • Production Ready • MIT License

---

## **Key Pages**

### **/architecture**
Deep dive into Four Pillars with interactive examples

### **/benchmarks**
Full benchmark suite, methodology, reproducible containers

### **/i18n**
Complete i18n guide with live locale switching demo

### **/vs-rails**
Honest comparison: when to use Dami vs Rails

### **/docs**
Full documentation with searchable API reference

---

**Design Notes:**
- Clean, minimal design
- Code examples everywhere
- Interactive demos where possible
- Fast load times (practice what we preach)
- Dark mode default (developers love it)
- Mobile-responsive (but desktop-first)