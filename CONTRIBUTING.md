# 🤝 Contributing to Dev Cleaner Utility

The Dev Cleaner Utility is an open-source project, and we **love** contributions from the community! Whether you are fixing a bug, adding a new cleanup routine, improving documentation, or just providing feedback, your help is essential.

## 🚀 Getting Started

To contribute, please follow the standard GitHub workflow:

1.  **Fork** the repository on GitHub.
2.  **Clone** your fork locally:
    ```bash
    git clone [https://github.com/your-username/dev-cleaner.git](https://github.com/your-username/dev-cleaner.git)
    cd dev-cleaner
    ```
3.  **Create a new branch** for your specific changes:
    ```bash
    git checkout -b feature/your-awesome-feature
    # OR
    git checkout -b fix/issue-name
    ```

## 🐞 Reporting Issues

If you find a bug or have a suggestion, please open a new **Issue** on the repository.

When reporting a bug, please include:

* **OS & Version:** (e.g., macOS Sonoma 14.5, Ubuntu 22.04)
* **Shell:** (e.g., zsh, bash)
* **Error Message:** The exact error output, if available.
* **Steps to Reproduce:** Clear, numbered steps to reliably reproduce the issue.

## ⚙️ Contribution Guidelines

### 📝 Bash Scripting Standards

Since this project is a **Bash Shell Script**, please adhere to these standards for portability and reliability:

| Guideline | Description |
| :--- | :--- |
| **Linting** | Ensure your code passes `shellcheck` (if possible) to avoid common shell pitfalls. |
| **Readability** | Use 4 spaces for indentation. |
| **Output** | Utilize the defined color variables (`$GREEN`, `$RED`, etc.) and the `print_item` helper function for all terminal output. |
| **Safety** | Be extremely cautious with `rm -rf`. Always use a preceding check (`if [ -d "$PATH" ]; then...`) before deleting directories. |

### 🛠️ Adding New Cleanup Routines

If you add a new cleanup function (e.g., cleaning up the Rust `cargo` cache):

1.  Define the function in the **Cleanup Functions** section (e.g., `cleanup_rust()`).
2.  Add a check for the existence of the tool/directory (`if command -v rustup &> /dev/null; then`).
3.  Add the new option to the interactive menu in `display_menu()`.
4.  Include a call to your new function in the **Clear All Caches (Option 1)** routine within `main_loop()`.

### 💬 Commit Message Format

We strongly recommend using the **Conventional Commits** format for clear commit history:

| Prefix | Use When... | Example |
| :--- | :--- | :--- |
| `feat:` | Adding a new feature (e.g., Docker cleanup). | `feat: add docker build cache cleanup routine` |
| `fix:` | Fixing a bug (e.g., corrected a path). | `fix: correct Android Studio cache path for Linux` |
| `docs:` | Changing documentation (README, CONTRIBUTING, etc.). | `docs: update install command in README` |
| `refactor:` | Restructuring code without fixing a bug or adding a feature. | `refactor: move helper functions to separate block` |

## 🌟 Submission Process

1.  Ensure your branch is up-to-date with the `main` branch of the original repository.
2.  Create a **Pull Request (PR)** targeting the `main` branch.
3.  In the PR description, explain your changes, mention any related issues, and provide test results (if applicable).

***

**Thank you for your time and effort in making the Dev Cleaner Utility the best it can be!**
