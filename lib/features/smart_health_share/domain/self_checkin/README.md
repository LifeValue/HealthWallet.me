# SMART Health Cards - Self Check-in

This folder will contain the implementation of the SMART Health Check-in Protocol as described in:

- [Proposal: SMART Health Check-in Protocol](https://www.linkedin.com/pulse/proposal-smart-health-check-in-protocol-josh-mandel-md-pdzmc/)
- [GitHub Demo](https://github.com/jmandel/smart-health-checkin-demo)

## Overview

The SMART Health Check-in Protocol enables remote health data sharing using `connect.healthwallet.me` (the connection engine), similar to how a torrent works. This allows patients to share health records, insurance data, and other paperwork with providers before arriving at the clinic.

## Future Implementation

This feature will be implemented in a future phase and will include:

- Request/response protocol for health data sharing
- Picker component for selecting patient apps
- Authorization and enrichment flows
- Direct data transmission using BroadcastChannel API
- Support for FHIR Questionnaires and pre-filled forms

## Related Features

- **LocalQR Code**: Time-based and proximity-based sharing (see `../local_qr/`)
- **Base SHC**: Standard SMART Health Cards generation (see `../shared/`)


