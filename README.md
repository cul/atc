# "Air Traffic Control"

DLST app for managing data flights to cloud storage.


## First-Time Setup (for developers)
1. Clone the repository:
```
git clone git@github.com:cul/atc.git
```

2. Install gem dependencies:
```
bundle install
```

3. Set up config files:
```
bundle exec rake atc:setup:config_files
```

4. Run database migrations:
```
bundle exec rake db:migrate
```

5. Install Javascript dependencies:
```
yarn
```

6. *(Assuming you are using VS Code)* Set up your IDE to locate TS modules and and activate typescript:
    <!-- If we decide to gitignore .yarn/sdks and .vscode: explicitly instruct people to download ZipFS -->
    1. Accept any recommended extension installations. You will need [ZipFS](https://marketplace.visualstudio.com/items?itemName=arcanis.vscode-zipfs) to go into any library's code.
    <!-- If we decide to gitignore .yarn/sdks and .vscode: 2. Install the VS Code SDK: `yarn dlx @yarnpkg/sdks vscode` -->
    2. Open a typescript file then open the command palette with `ctrl+shift+p` and run "Select TypeScript Version". Pick "Use Workspace Version".


> [!Note]
> See [yarn documentation](https://yarnpkg.com/getting-started/editor-sdks#vscode) for more details or instructions if using a different IDE

7. Seed the database with necessary values for operation:
```
rails db:seed
```

8. Start the vite dev server:
```
yarn start:dev # or bin/vite dev
```

9. Start the application using `rails server`:
```
bin/rails server # or rails s -p 3000
```

## S3 Browser App
The S3 browser app will be located under the `/browser` route. At that route, a React SPA will be loaded into the client.
It requires authentication to view.

## Contributing and CI
Before making a PR, you should check that all tests are passing and both linters (ESLint and rubocop) are happy. We check all of these during github actions continuous integrations.

To run all of the CI actions:
```
  bundle exec atc:ci
```

To run tests:
```
  bundle exec rake atc:ci_specs
```

To run the cop:
```
  bundle exec rake atc:rubocop
```

To run ESLint:
```
  bundle exec rake atc:eslint
```