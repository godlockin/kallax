name: Feature Request
description: Suggest a new feature for KALLAX
title: "[FEATURE] "
labels: ["enhancement"]
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        ## Feature Request

        Thanks for suggesting a new feature!

  - type: textarea
    id: problem
    attributes:
      label: Problem Statement
      description: What problem does this feature solve?
      placeholder: Describe the problem here...
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: Proposed Solution
      description: How would you solve this problem?
      placeholder: Describe your proposed solution...
    validations:
      required: true

  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives Considered
      description: Any alternative solutions you've considered?
      placeholder: Describe alternatives...

  - type: textarea
    id: context
    attributes:
      label: Additional Context
      description: Any other context or mockups?
      placeholder: Add any other context here...

  - type: checkboxes
    id: checklist
    attributes:
      label: Checklist
      options:
        - label: I have searched existing issues/discussions
          required: true
        - label: This is a new feature (not a duplicate)
          required: true
        - label: I am willing to help implement this feature
          required: false
