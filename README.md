# Corporate Identity Registry Smart Contract

A comprehensive blockchain-based registry for managing Corporate Identity Numbers (CINs) with transparent, immutable record-keeping for global corporate entity identification.

## Overview

The Corporate Identity Registry is a decentralized smart contract built on the Stacks blockchain using Clarity. It provides a secure, transparent system for registering, managing, and validating corporate identities while ensuring regulatory compliance through immutable audit trails.

## Key Features

- **Secure Registration**: Register corporate identities with comprehensive validation
- **Ownership Management**: Track and transfer ownership of corporate identities
- **Audit Trails**: Immutable history of all status changes and modifications
- **Access Control**: Multi-level administrative permissions system
- **Batch Operations**: Process multiple registrations efficiently
- **Expiration Handling**: Automated lifecycle management for registrations

## Core Data Structures

### Corporate Identity Registry
Stores comprehensive information for each CIN including:
- Company official name and business structure
- Jurisdiction code and issuing organization
- Registration and expiration timestamps
- Current status and ownership details

### Portfolio Holdings
Tracks all CINs owned by each principal address for easy portfolio management.

### Audit Logs
Maintains complete historical records of all status changes and modifications.

## Registration Status Types

- `ACTIVE` - Currently valid and operational
- `EXPIRED` - Registration has passed expiration date
- `SUSPENDED` - Temporarily inactive by administrative action
- `RETIRED` - Permanently deactivated
- `MERGED` - Entity has been merged with another
- `DUPLICATE` - Identified as duplicate registration
- `LAPSED` - Registration has lapsed due to non-renewal

## Main Functions

### Administrative Functions
- `transfer-primary-ownership` - Transfer contract ownership
- `authorize-new-administrator` - Grant admin privileges
- `revoke-administrator-privileges` - Remove admin access

### Registration Management
- `register-corporate-identity-number` - Register new CIN
- `extend-cin-expiration-date` - Extend registration validity
- `update-company-information` - Modify company details
- `update-registration-status` - Change registration status
- `transfer-cin-ownership` - Transfer CIN to new owner

### Query Functions
- `get-cin-details` - Retrieve complete CIN information
- `is-cin-active-and-valid` - Check if CIN is currently valid
- `get-principal-cin-portfolio` - Get all CINs owned by address
- `get-cin-audit-trail` - Retrieve modification history
- `validate-cin-comprehensive` - Perform full validation check

### Batch Operations
- `process-expired-cin-batch` - Process multiple expired CINs

## Access Control

### Administrative Privileges Required For:
- New CIN registration
- Status modifications
- Batch processing operations
- User privilege management

### Owner/Admin Privileges Required For:
- Extending expiration dates
- Updating company information
- Transferring ownership

## Validation Rules

### CIN Format
- Exactly 20 characters (ASCII)
- Must be unique across the registry

### Company Information
- Official name: 1-256 UTF-8 characters
- Jurisdiction code: Exactly 2 ASCII characters
- Business structure: 1-100 UTF-8 characters
- Issuing organization: 1-100 UTF-8 characters

### Date Validation
- Expiration dates must be in the future
- Extensions must increase the current expiration date

## Error Codes

### Access Control (100-102)
- `100`: Unauthorized access
- `101`: Insufficient privileges
- `102`: Invalid administrator

### Data Validation (200-208)
- `200`: Invalid CIN format
- `201`: Invalid company name
- `202`: Invalid jurisdiction code
- `203`: Invalid business form
- `204`: Invalid certifying authority
- `205`: Invalid corporate address
- `206`: Invalid date range
- `207`: Invalid status value
- `208`: Invalid input parameters

### Business Logic (300-305)
- `300`: Duplicate CIN registration
- `301`: CIN record not found
- `302`: CIN status inactive
- `303`: CIN status expired
- `304`: CIN already expired
- `305`: Ownership transfer denied

## Usage Examples

### Register a New Corporate Identity
```clarity
(register-corporate-identity-number 
  "12345678901234567890"
  u"Example Corporation Ltd"
  u1000000
  "US"
  u"Limited Liability Company"
  u"State Registration Authority")
```

### Check if CIN is Valid
```clarity
(is-cin-active-and-valid "12345678901234567890")
```

### Transfer Ownership
```clarity
(transfer-cin-ownership "12345678901234567890" 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Security Considerations

- All administrative functions require proper authorization
- CIN format validation prevents malformed entries
- Audit trails provide complete transparency
- Ownership validation prevents unauthorized transfers
- Input sanitization protects against invalid data

