name: Bug Report
description: Report a bug to help us improve KALLAX
title: "[BUG] "
labels: ["bug"]
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        ## Bug Report

        Thanks for taking the time to report a bug!

  - type: textarea
    id: description
    attributes:
      label: Bug Description
      description: A clear description of the bug
      placeholder: Describe the bug here...
    validations:
      required: true

  - type: textarea
    id: reproduction
    attributes:
      label: Reproduction Steps
      description: Steps to reproduce the bug
      placeholder: |
        1. Go to '...'
        2. Run '...'
        3. See error
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
      description: What you expected to happen
    validations:
      required: true

  - type: textarea
    id: actual
    attributes:
      label: Actual Behavior
      description: What actually happened
    validations:
      required: true

  - type: input
    id: version
    attributes:
      label: KALLAX Version
      description: Output of `kallax --version` or commit hash
      placeholder: v3.32.15

  - type: dropdown
    id: os
    attributes:
      label: OS
      options:
        - macOS
        - Linux
        - Windows
        - Other
    validations:
      required: true

  - type: textarea
    id: logs
    attributes:
      label: Relevant Logs
      description: Paste any relevant log output
      placeholder: |
        ```
        [paste logs here]
        ```

  - type: textarea
    id: context
    attributes:
      label: Additional Context
      description: Any other context about the problem
      placeholder: Add any other context here...

  - type: checkboxes
    id: checklist
    attributes:
      label: Checklist
      options:
        - label: I have searched existing issues
          required: true
        - label: I have verified the bug is reproducible
          required: true
        - label: I have included relevant logs
          required: false
