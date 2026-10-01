import os
import sys
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import parse_xml, OxmlElement
from docx.oxml.ns import nsdecls, qn

sys.path.append(r'c:\PROJECTS\visaia\scripts')
from docx_helpers import (
    set_cell_background, set_cell_margins, set_table_borders,
    format_table_header, format_data_row, add_heading_1,
    add_heading_2, add_heading_3, add_callout
)

def create_full_data_dictionary():
    doc = docx.Document()

    # Set page margins (1 inch all around)
    for section in doc.sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)

    # -------------------------------------------------------------
    # Document Title & Metadata
    # -------------------------------------------------------------
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(0)
    title_p.paragraph_format.space_after = Pt(2)
    r_title = title_p.add_run("VISAIA System Data Dictionary")
    r_title.font.name = "Segoe UI"
    r_title.font.size = Pt(22)
    r_title.font.bold = True
    r_title.font.color.rgb = RGBColor(27, 67, 50)

    sub_p = doc.add_paragraph()
    sub_p.paragraph_format.space_before = Pt(0)
    sub_p.paragraph_format.space_after = Pt(12)
    r_sub = sub_p.add_run("Comprehensive Technical & Physical Data Specification across the 12-Phase System Process Flow\nDual-Platform Mapping: Flutter Mobile App (visaia) & Next.js Web Dashboard (visaia-dashboard)")
    r_sub.font.name = "Segoe UI"
    r_sub.font.size = Pt(10.5)
    r_sub.font.italic = True
    r_sub.font.color.rgb = RGBColor(82, 121, 111)

    # Metadata Box
    add_callout(
        doc,
        "Specification Metadata",
        "Document Version: 2.0 (Complete System Redo) | System Architecture: Firebase Cloud Firestore NoSQL + YOLO AI Inference API | "
        "User Roles Supported: Smallholder Farmers (Mobile App), MAO Officers (Municipal Agricultural Office Web Dashboard), "
        "RCPC Specialists (Regional Crop Protection Center Web Dashboard).",
        bg_hex="E8F5E9",
        border_color="2E7D32"
    )

    # -------------------------------------------------------------
    # Section 1: Executive Summary & Architecture Overview
    # -------------------------------------------------------------
    add_heading_1(doc, "1. Executive Summary & Architecture Overview")

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run(
        "VISAIA is an integrated AI-powered pest surveillance, early warning, and farm lifecycle management ecosystem "
        "engineered for the Department of Agriculture (DA), Municipal Agricultural Offices (MAO), Regional Crop Protection Centers (RCPC), "
        "and smallholder farmers. The ecosystem operates across three interconnected tiers:\n"
        "1. Mobile Client (Flutter): Enables offline-first GPS farm boundary mapping, field scouting, automated trap logging, "
        "AI camera pest detection, mitigation tracking, and harvest revenue auditing.\n"
        "2. Admin Web Dashboard (Next.js & React Leaflet): Provides dual role-based control centers (MAO District Dashboard for farmer verification and local crop oversight; "
        "RCPC Regional Dashboard for AI diagnosis validation, GIS risk map modeling, and regional advisory broadcasts).\n"
        "3. AI Inference Service (FastAPI / YOLO): Processes scouting imagery in real time, detecting Fall Armyworm (FAW) and associated pests, "
        "evaluating life stage instars, generating bounding box coordinates, and formulating IPM treatment advisories."
    )
    r.font.name = "Segoe UI"
    r.font.size = Pt(9.5)
    r.font.color.rgb = RGBColor(30, 41, 59)

    add_callout(
        doc,
        "NoSQL Firestore Document Hierarchy vs. Relational Logical Model",
        "While the system's logical entity model is presented in this specification with primary and foreign keys (for database normalization and capstone ERD alignment), "
        "the physical implementation is deployed on Google Cloud Firestore. Top-level collections ('users', 'farmers', 'reports', 'validations', 'alerts', 'clustered_reports') "
        "are paired with scoped hierarchical subcollections ('users/{uid}/farms', 'users/{uid}/fields', 'users/{uid}/cycles/{cycleId}/weeks', "
        "'users/{uid}/cycles/{cycleId}/dailyLogs/{dayId}/activities', and 'users/{uid}/notifications'). Both representations are fully documented below.",
        bg_hex="F0FDF4",
        border_color="16A34A"
    )

    # -------------------------------------------------------------
    # Section 2: 12-Phase System Process Flow & Data Entity Mapping
    # -------------------------------------------------------------
    add_heading_1(doc, "2. 12-Phase System Process Flow & Data Entity Mapping")

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run(
        "The complete farming, surveillance, and mitigation lifecycle is governed by the 12-Phase System Process Flow. "
        "Each phase corresponds to specific functional modules and database entities:"
    )
    r.font.name = "Segoe UI"
    r.font.size = Pt(9.5)

    # 12-Phase Table
    phase_cols = [Inches(0.9), Inches(1.8), Inches(2.2), Inches(1.9)]
    phase_table = doc.add_table(rows=13, cols=4)
    phase_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    phase_table.autofit = False
    set_table_borders(phase_table, color="D1D5DB")

    headers = ["Phase #", "Lifecycle Phase Name", "Core Functional Scope", "Primary Data Entities Involved"]
    for i, h in enumerate(headers):
        phase_table.cell(0, i).text = h
    format_table_header(phase_table.rows[0], phase_cols, bg_color="1B4332")

    phase_data = [
        ("Phase 01", "Account Approval & Registration", "Farmer onboarding, RSBSA ID capture, ID document upload, LGU-MAO verification review.", "USERS, FARMERS, VALIDATION_REQUESTS"),
        ("Phase 02", "Farm Setup & Geospatial Mapping", "GPS boundary polygon capture, acreage calculation, field subdivision, crop assignment.", "FARM_LOCATIONS (FARMS), FARM_FIELDS"),
        ("Phase 03", "Cropping Setup & Cycle Initialization", "Growing cycle initiation, botanical variety selection, planting date, expected harvest date.", "CROPPING_CYCLES, PLANTING_RECORDS"),
        ("Phase 04", "Field Monitoring & Routine Logging", "Weekly DAP/stage tracking, daily operations (irrigation, fertilizer, weeding), trap inspections.", "FIELD_MONITORING_TASKS, DAILY_ACTIVITY_LOGS, TRAP_MONITORING"),
        ("Phase 05", "AI Pest Detection & Image Inference", "Field image capture, YOLO AI inference, bounding box detection, instar/severity scoring.", "PEST_REPORTS, AI_PROCESSING, AI_DETECTIONS"),
        ("Phase 06", "Expert Validation Queue", "RCPC specialist queue, visual diagnosis verification, species/severity correction, expert notes.", "VALIDATION_QUEUE, EXPERT_VALIDATION"),
        ("Phase 07", "GIS Risk Mapping & Proximity Alerts", "Spatial clustering, outbreak radius calculation, wind trajectory analysis, affected farm identification.", "RISK_ZONES, RISK_ZONE_SOURCE, SPATIAL_CLUSTERS"),
        ("Phase 08", "Mitigation Advisories & Alert Dispatch", "Regional bulletins, IPM protocol dissemination, targeted in-app/push alerts.", "ALERTS, ALERT_RECIPIENTS, REGIONAL_ADVISORIES, REGIONAL_ADVISORY_ZONES"),
        ("Phase 09", "Management Actions & Threat Resolution", "Farmer control action execution (chemical/biological/cultural), clearance report with explanation.", "MANAGEMENT_ACTIONS, REPORT_RESOLUTION"),
        ("Phase 10", "LGU-MAO Monitoring & Local Analytics", "Barangay-level infestation monitoring, municipal crop distribution, verification auditing.", "LGU_DISTRICT_METRICS, HISTORICAL_INVESTIGATIONS"),
        ("Phase 11", "Harvest Recording & Yield Documentation", "Harvest completion, yield quantification (good vs damaged), loss rate calculation, market price.", "HARVEST_RECORDS, CROPPING_CYCLES"),
        ("Phase 12", "Cycle Completion & Financial Audit", "Cost accounting (seeds, fertilizer, labor, control), net profit calculation, seasonal archive.", "FINANCIAL_OUTCOMES, CROPPING_CYCLES (Archive)")
    ]

    for row_idx, data in enumerate(phase_data, start=1):
        row = phase_table.rows[row_idx]
        for col_idx, text in enumerate(data):
            row.cells[col_idx].text = text
        format_data_row(row, phase_cols, is_even=(row_idx % 2 == 0), font_size=8.5)

    doc.add_paragraph().paragraph_format.space_after = Pt(8)

    # -------------------------------------------------------------
    # Section 3: Master Data Entity Catalog (Summary Table)
    # -------------------------------------------------------------
    add_heading_1(doc, "3. Master Data Entity Catalog (Summary Table)")

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run(
        "Below is the complete catalog of all 32 logical data entities and physical Firestore collections in the VISAIA ecosystem:"
    )
    r.font.name = "Segoe UI"
    r.font.size = Pt(9.5)

    cat_cols = [Inches(0.4), Inches(1.8), Inches(1.8), Inches(1.5), Inches(1.3)]
    cat_table = doc.add_table(rows=33, cols=5)
    cat_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    cat_table.autofit = False
    set_table_borders(cat_table, color="D1D5DB")

    cat_headers = ["#", "Entity / Logical Table", "Physical Storage Path / Model", "Primary Key", "Related Entities (Foreign Keys)"]
    for i, h in enumerate(cat_headers):
        cat_table.cell(0, i).text = h
    format_table_header(cat_table.rows[0], cat_cols, bg_color="1B4332")

    entities_summary = [
        ("1", "USERS", "users/{uid}", "uid (PK)", "FARMERS, VALIDATION_REQUESTS, EXPERT_VALIDATION, ALERTS"),
        ("2", "FARMERS", "farmers/{farmerId} & users/{uid}", "id / uid (PK)", "USERS, FARMS, CROPPING_CYCLES, PEST_REPORTS"),
        ("3", "VALIDATION_REQUESTS", "farmers/{id} (status: pending)", "id (PK)", "FARMERS, USERS (MAO Admin)"),
        ("4", "FARM_LOCATIONS (FARMS)", "users/{uid}/farms/{farmId}", "id (PK)", "FARMERS, FARM_FIELDS, RISK_ZONES"),
        ("5", "FARM_FIELDS", "users/{uid}/fields/{fieldId}", "id (PK)", "FARMS, CROPPING_CYCLES, PEST_REPORTS, TRAP_MONITORING"),
        ("6", "CROPPING_CYCLES", "users/{uid}/cycles/{cycleId}", "id (PK)", "FARMS, FARM_FIELDS, PLANTING_RECORDS, HARVEST_RECORDS"),
        ("7", "PLANTING_RECORDS", "users/{uid}/cycles/{cycleId} (Embedded)", "id / cycleId (PK)", "CROPPING_CYCLES"),
        ("8", "FIELD_MONITORING_TASKS", "users/{uid}/cycles/{cycleId}/weeks/{weekId}", "id / weekId (PK)", "CROPPING_CYCLES, DAILY_ACTIVITY_LOGS"),
        ("9", "DAILY_ACTIVITY_LOGS", "users/{uid}/cycles/{cycleId}/dailyLogs/{dayId}/activities/{actId}", "id (PK)", "CROPPING_CYCLES, FIELD_MONITORING_TASKS"),
        ("10", "TRAP_MONITORING", "inspect_traps / subcollections", "id (PK)", "FARM_FIELDS, CROPPING_CYCLES, PEST_REPORTS"),
        ("11", "PEST_REPORTS", "reports/{reportId}", "id (PK)", "FARMERS, CROPPING_CYCLES, AI_PROCESSING, VALIDATION_QUEUE"),
        ("12", "AI_PROCESSING", "reports/{reportId} (Inference Metadata)", "id / reportId (PK)", "PEST_REPORTS, AI_DETECTIONS"),
        ("13", "AI_DETECTIONS", "reports/{reportId} (boxes, stage, risk)", "id / reportId (PK)", "PEST_REPORTS, EXPERT_VALIDATION, ADVISORIES"),
        ("14", "VALIDATION_QUEUE", "validations/{validationId}", "id (PK)", "PEST_REPORTS, USERS (RCPC Specialist)"),
        ("15", "EXPERT_VALIDATION", "validations/{validationId} & reports/{id}", "id (PK)", "PEST_REPORTS, USERS (Reviewer), ADVISORIES"),
        ("16", "MITIGATION_ADVISORIES", "reports/{reportId} (treatment field)", "id / reportId (PK)", "AI_DETECTIONS, EXPERT_VALIDATION, FARMERS"),
        ("17", "MANAGEMENT_ACTIONS", "reports/{id} & activity logs", "id (PK)", "FARMERS, PEST_REPORTS, DAILY_ACTIVITY_LOGS"),
        ("18", "REPORT_RESOLUTION", "reports/{id} (resolutionExplanation)", "id / reportId (PK)", "PEST_REPORTS, FARMERS"),
        ("19", "RISK_ZONES", "clustered_reports / map polygon layers", "id (PK)", "RISK_ZONE_SOURCE, ALERTS, FARMS"),
        ("20", "RISK_ZONE_SOURCE", "clustered_reports/{id} (report linkages)", "id (PK)", "RISK_ZONES, PEST_REPORTS"),
        ("21", "SPATIAL_CLUSTERS", "clustered_reports/{clusterId}", "id (PK)", "PEST_REPORTS, RISK_ZONES, FARMS"),
        ("22", "ALERTS", "alerts/{alertId} & alertDrafts/{id}", "id (PK)", "RISK_ZONES, ALERT_RECIPIENTS, PEST_REPORTS"),
        ("23", "ALERT_RECIPIENTS", "users/{uid}/notifications/{notifId}", "id (PK)", "ALERTS, USERS (Farmers)"),
        ("24", "REGIONAL_ADVISORIES", "alerts/{id} (type: regional)", "id (PK)", "USERS (RCPC), REGIONAL_ADVISORY_ZONES"),
        ("25", "REGIONAL_ADVISORY_ZONES", "alerts/{id} (affectedRegions array)", "id (PK)", "REGIONAL_ADVISORIES, RISK_ZONES"),
        ("26", "PEST_REFERENCES", "pestLibrary/{pestSlug}", "id / slug (PK)", "PEST_LIFESTAGE_INFO, IPM_RECOMMENDATIONS"),
        ("27", "PEST_LIFESTAGE_INFO", "pestLibrary/{slug} (lifecycle object)", "id (PK)", "PEST_REFERENCES"),
        ("28", "IPM_RECOMMENDATIONS", "pestLibrary/{slug} (management object)", "id (PK)", "PEST_REFERENCES, PEST_REPORTS"),
        ("29", "HISTORICAL_INVESTIGATIONS", "reports / past cycles historical archive", "id (PK)", "FARMERS, CROPPING_CYCLES, RISK_ZONES"),
        ("30", "HARVEST_RECORDS", "users/{uid}/cycles/{cycleId} (harvest fields)", "id / cycleId (PK)", "CROPPING_CYCLES, FINANCIAL_OUTCOMES"),
        ("31", "FINANCIAL_OUTCOMES", "users/{uid}/cycles/{cycleId} (audit fields)", "id / cycleId (PK)", "CROPPING_CYCLES, HARVEST_RECORDS"),
        ("32", "SYSTEM_CONFIG (APP_RELEASES)", "app_releases/config", "id (PK)", "USERS (Mobile App Clients)")
    ]

    for row_idx, data in enumerate(entities_summary, start=1):
        row = cat_table.rows[row_idx]
        for col_idx, text in enumerate(data):
            row.cells[col_idx].text = text
        format_data_row(row, cat_cols, is_even=(row_idx % 2 == 0), font_size=8)

    doc.add_paragraph().paragraph_format.space_after = Pt(12)

    # -------------------------------------------------------------
    # Section 4: Detailed Physical & Logical Data Dictionary
    # -------------------------------------------------------------
    add_heading_1(doc, "4. Detailed Physical & Logical Data Dictionary")

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run(
        "This section details every field, data type, key constraint, nullability, physical Firestore document key, description, "
        "and valid value enumerations across all system entities:"
    )
    r.font.name = "Segoe UI"
    r.font.size = Pt(9.5)

    # Define all detailed entity dictionaries
    detailed_entities = [
        {
            "id": "4.1",
            "name": "USERS",
            "phase": "Phase 01: Account Approval & Registration",
            "desc": "Master authentication and role-based access control table for farmers, MAO administrators, and RCPC specialists.",
            "path": "users/{uid}",
            "fields": [
                ("uid", "String (UUID)", "PK / Required", "uid", "Unique Firebase Authentication User ID.", "e.g. 'usr_89f4b7a12'"),
                ("email", "String", "Unique / Required", "email", "User email address used for system login.", "e.g. 'farmer.juan@gmail.com'"),
                ("name / fullName", "String", "Required", "name / fullName", "Full legal name of the user.", "e.g. 'Juan Dela Cruz'"),
                ("firstName", "String", "Optional", "firstName", "First name of user/farmer.", "e.g. 'Juan'"),
                ("middleName", "String", "Optional", "middleName", "Middle name of user/farmer.", "e.g. 'Santos'"),
                ("lastName", "String", "Optional", "lastName", "Last name / family name.", "e.g. 'Dela Cruz'"),
                ("extension", "String", "Optional", "extension", "Name suffix/extension.", "'None', 'Jr.', 'Sr.', 'II', 'III'"),
                ("role", "String (Enum)", "Required", "role", "System authorization level.", "'farmer', 'mao_admin', 'rcpc_admin', 'admin'"),
                ("userType", "String (Enum)", "Required", "userType", "Platform user classification.", "'app' (mobile client), 'dashboard' (web admin)"),
                ("phone / contactNumber", "String", "Optional", "phone", "Mobile telephone number.", "e.g. '+639171234567'"),
                ("address", "String", "Optional", "address", "Physical residential address.", "e.g. 'Purok 4, Barangay San Jose'"),
                ("district", "String", "Optional", "district", "Assigned agricultural district or municipality.", "e.g. 'District 2', 'Bacolod City'"),
                ("isVerified", "Boolean", "Required", "isVerified / verified", "Account approval flag verified by MAO officer.", "true, false (default: false)"),
                ("status", "String (Enum)", "Required", "status", "Account approval lifecycle status.", "'pending', 'approved', 'rejected', 'active'"),
                ("createdAt", "Timestamp", "Required", "createdAt", "Account creation date and time.", "ServerTimestamp"),
                ("lastLogin", "Timestamp", "Optional", "lastLogin", "Timestamp of most recent system login.", "Timestamp")
            ]
        },
        {
            "id": "4.2",
            "name": "FARMERS",
            "phase": "Phase 01: Account Approval & Registration",
            "desc": "Stores farmer agricultural profiles, demographic attributes, RSBSA registrations, and document verification submissions.",
            "path": "farmers/{farmerId} & users/{uid}",
            "fields": [
                ("id / uid", "String (UUID)", "PK / FK (USERS.uid)", "uid / id", "Primary identifier linking to USERS account.", "e.g. 'usr_89f4b7a12'"),
                ("fullName", "String", "Required", "fullName", "Full name of the registered farmer.", "e.g. 'Juan Dela Cruz'"),
                ("email", "String", "Required", "email", "Contact email address.", "e.g. 'farmer.juan@gmail.com'"),
                ("sex", "String (Enum)", "Required", "sex", "Gender / biological sex of the farmer.", "'Male', 'Female', 'Other'"),
                ("birthdate", "String / Date", "Required", "birthdate", "Birthdate in ISO-8601 format.", "e.g. '1985-04-12'"),
                ("farmSize", "Double (Hectares)", "Required", "farmSize", "Declared total agricultural farm area in hectares.", "e.g. 2.5"),
                ("hasRsbsaId", "Boolean", "Required", "hasRsbsaId", "Flag indicating whether farmer possesses RSBSA registration.", "true, false"),
                ("rsbsaId", "String", "Optional / Unique", "rsbsaId", "Registry System for Basic Sectors in Agriculture ID.", "e.g. 'RSBSA-06-45-00129'"),
                ("skipFarmerId", "Boolean", "Required", "skipFarmerId", "Flag indicating if farmer ID upload was bypassed with RSBSA.", "true, false"),
                ("farmerIdImage", "String (Base64/URL)", "Optional", "farmerIdImage", "Base64 encoded string or Cloud Storage URL of ID.", "Base64 data or Firebase URL"),
                ("farmerIdFileName", "String", "Optional", "farmerIdFileName", "Original filename of uploaded ID document.", "e.g. 'farmer_id_card.jpg'"),
                ("status", "String (Enum)", "Required", "status", "Verification status evaluated by MAO.", "'pending', 'verified', 'rejected'"),
                ("verifiedAt", "Timestamp", "Optional", "verifiedAt / verificationDate", "Timestamp when MAO approved the account.", "Timestamp"),
                ("verifiedBy", "String (FK)", "Optional", "verifiedBy", "UID of MAO administrator who approved registration.", "e.g. 'mao_officer_44'"),
                ("rejectionReason", "String", "Optional", "rejectionReason", "Justification text provided if application rejected.", "e.g. 'Invalid RSBSA document image'"),
                ("createdAt", "Timestamp", "Required", "createdAt", "Application submission timestamp.", "ServerTimestamp")
            ]
        },
        {
            "id": "4.3",
            "name": "VALIDATION_REQUESTS",
            "phase": "Phase 01: Account Approval & Registration",
            "desc": "Audit and queue record tracking farmer account registration submissions for LGU-MAO administrative approval.",
            "path": "farmers/{id} (status: pending) / audit log",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique validation request transaction identifier.", "e.g. 'req_0012'"),
                ("farmerId", "String (FK)", "FK (FARMERS.id)", "farmerId / uid", "Reference to the submitting farmer.", "e.g. 'usr_89f4b7a12'"),
                ("submissionDate", "Timestamp", "Required", "createdAt", "Timestamp when registration was submitted.", "ServerTimestamp"),
                ("status", "String (Enum)", "Required", "status", "Request queue review status.", "'pending', 'approved', 'rejected'"),
                ("reviewedBy", "String (FK)", "Optional", "verifiedBy", "UID of MAO officer assigned to the review.", "e.g. 'mao_admin_09'"),
                ("reviewedAt", "Timestamp", "Optional", "verifiedAt", "Timestamp when verification decision was finalized.", "Timestamp"),
                ("reviewNotes", "String", "Optional", "rejectionReason", "Administrative remarks or verification notes.", "e.g. 'RSBSA verified in registry'")
            ]
        },
        {
            "id": "4.4",
            "name": "FARM_LOCATIONS (FARMS)",
            "phase": "Phase 02: Farm Setup & Geospatial Mapping",
            "desc": "Stores geospatial boundary polygons, total acreage, centroid GPS coordinates, and parcels for each farm.",
            "path": "users/{uid}/farms/{farmId}",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique Farm Parcel Identifier.", "e.g. 'farm_east_parcel_01'"),
                ("farmerId", "String (FK)", "FK (USERS.uid)", "farmerId / parent path", "Owner farmer UID.", "e.g. 'usr_89f4b7a12'"),
                ("name", "String", "Required", "name", "Descriptive name given to the farm parcel.", "e.g. 'Green Valley Corn Farm'"),
                ("acres", "Double", "Required", "acres", "Total area calculated automatically in acres.", "e.g. 3.75"),
                ("hectares", "Double", "Optional", "hectares", "Total area converted to hectares.", "e.g. 1.52"),
                ("boundaries", "Array<LatLng>", "Required", "boundaries", "List of GPS polygon vertex coordinates defining perimeter.", "[{'lat': 10.7202, 'lng': 122.5621}, ...]"),
                ("location", "Map<lat, lng>", "Optional", "location", "Centroid GPS coordinates of the farm parcel.", "{'lat': 10.7202, 'lng': 122.5621}"),
                ("district", "String", "Optional", "district", "Administrative agricultural district.", "e.g. 'District 2'"),
                ("createdAt", "Timestamp", "Required", "createdAt", "Farm registration timestamp.", "ServerTimestamp")
            ]
        },
        {
            "id": "4.5",
            "name": "FARM_FIELDS",
            "phase": "Phase 02: Farm Setup & Geospatial Mapping",
            "desc": "Stores individual field plot subdivisions within a farm parcel, specific boundary polygons, acreage, and assigned crops.",
            "path": "users/{uid}/fields/{fieldId}",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique Field Plot Identifier.", "e.g. 'field_plot_north_01'"),
                ("farmId", "String (FK)", "FK (FARMS.id)", "farmId", "Parent Farm Parcel ID.", "e.g. 'farm_east_parcel_01'"),
                ("farmerId", "String (FK)", "FK (USERS.uid)", "farmerId / parent path", "Owner farmer UID.", "e.g. 'usr_89f4b7a12'"),
                ("name", "String", "Required", "name", "Descriptive field plot name.", "e.g. 'North Field - Sweet Corn'"),
                ("acres", "Double", "Required", "acres", "Area of this specific field in acres.", "e.g. 1.25"),
                ("crop", "String", "Optional", "crop", "Current primary crop planted on this field.", "e.g. 'Corn', 'Rice', 'Vegetables'"),
                ("boundaries", "Array<LatLng>", "Required", "boundaries", "List of GPS coordinates defining field boundaries.", "[{'lat': 10.7205, 'lng': 122.5625}, ...]"),
                ("createdAt", "Timestamp", "Required", "createdAt", "Field creation timestamp.", "ServerTimestamp")
            ]
        },
        {
            "id": "4.6",
            "name": "CROPPING_CYCLES",
            "phase": "Phase 03: Cropping Setup & Cycle Initialization",
            "desc": "Tracks seasonal planting cycles, growth stage progress, botanical varieties, seed densities, and harvest statuses.",
            "path": "users/{uid}/cycles/{cycleId}",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique Cropping Cycle Identifier.", "e.g. 'cycle_2026_q2_01'"),
                ("farmId", "String (FK)", "FK (FARMS.id)", "farmId", "Associated Farm ID.", "e.g. 'farm_east_parcel_01'"),
                ("fieldId", "String (FK)", "FK (FARM_FIELDS.id)", "fieldId", "Associated Field ID.", "e.g. 'field_plot_north_01'"),
                ("fieldName", "String", "Optional", "fieldName", "Cached field plot name for rapid UI display.", "e.g. 'North Field'"),
                ("cycleName", "String", "Required", "cycleName", "Title/Name of the cropping cycle.", "e.g. 'Wet Season Corn 2026'"),
                ("cropVariety", "String", "Required", "cropVariety", "Specific crop variety/hybrid planted.", "e.g. 'Pioneer 30T80 Yellow Corn'"),
                ("plantingDate", "Timestamp", "Required", "plantingDate", "Date seeds were sown.", "Timestamp"),
                ("harvestDate", "Timestamp", "Required", "harvestDate", "Estimated / Target harvest date.", "Timestamp"),
                ("actualHarvestDate", "Timestamp", "Optional", "actualHarvestDate", "Actual date harvest was completed.", "Timestamp"),
                ("seedDensity", "Double", "Optional", "seedDensity", "Sowing density rate in kg/ha or seeds/sqm.", "e.g. 20.0"),
                ("growthStage", "String (Enum)", "Optional", "growthStage / statusText", "Current phenological growth stage.", "'SEEDLING', 'EARLY_WHORL', 'LATE_WHORL', 'TASSELING_SILKING', 'GRAIN_FILLING', 'MATURITY'"),
                ("isCompleted", "Boolean", "Required", "isCompleted", "Cycle completion flag (persisted after harvest/audit).", "true, false (default: false)"),
                ("status", "String (Enum)", "Required", "status", "Cycle operational status.", "'growing', 'active', 'harvested', 'completed', 'failed'"),
                ("statusText", "String", "Optional", "statusText", "Human-readable status description.", "e.g. 'Vegetative Stage (Day 34)'"),
                ("income / netIncome", "Double", "Optional", "income / netIncome", "Final audited net profit/loss (PHP).", "e.g. 45000.00"),
                ("grossIncome / totalValue", "Double", "Optional", "grossIncome / totalValue", "Total gross revenue generated from harvest.", "e.g. 72000.00"),
                ("createdAt", "Timestamp", "Required", "createdAt", "Cycle initialization timestamp.", "ServerTimestamp")
            ]
        },
        {
            "id": "4.7",
            "name": "PLANTING_RECORDS",
            "phase": "Phase 03: Cropping Setup & Cycle Initialization",
            "desc": "Detailed planting specification recorded upon initiating a new cycle (seed hybrid, density, germination conditions).",
            "path": "users/{uid}/cycles/{cycleId} (embedded/subcollection)",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique planting record identifier.", "e.g. 'plt_001'"),
                ("cycleId", "String (FK)", "FK (CROPPING_CYCLES.id)", "cycleId", "Parent cropping cycle ID.", "e.g. 'cycle_2026_q2_01'"),
                ("plantingDate", "Timestamp", "Required", "plantingDate", "Exact date planting was executed.", "Timestamp"),
                ("seedType / Variety", "String", "Required", "cropVariety", "Seed variety name and classification.", "e.g. 'Hybrid Yellow Corn'"),
                ("quantity / Density", "Double", "Required", "seedDensity", "Quantity of seed sown or density rate.", "e.g. 18.5"),
                ("sowingMethod", "String", "Optional", "sowingMethod", "Planting method employed.", "e.g. 'Direct Seeding', 'Transplanting'"),
                ("spacingRowCm", "Double", "Optional", "spacingRowCm", "Row-to-row spacing distance in cm.", "e.g. 75.0"),
                ("spacingHillCm", "Double", "Optional", "spacingHillCm", "Hill-to-hill spacing distance in cm.", "e.g. 20.0")
            ]
        },
        {
            "id": "4.8",
            "name": "FIELD_MONITORING_TASKS",
            "phase": "Phase 04: Field Monitoring & Routine Logging",
            "desc": "Weekly phenological milestone timeline tracking Days After Planting (DAP), scouting completion, and scheduled field tasks.",
            "path": "users/{uid}/cycles/{cycleId}/weeks/{weekId}",
            "fields": [
                ("id / weekId", "String", "PK", "weekId", "Identifier for weekly milestone (e.g. 'week_1').", "e.g. 'week_3'"),
                ("cycleId", "String (FK)", "FK (CROPPING_CYCLES.id)", "cycleId", "Parent cropping cycle ID.", "e.g. 'cycle_2026_q2_01'"),
                ("weekNumber", "Integer", "Required", "weekNumber", "Week index from planting (1, 2, 3... 16).", "e.g. 3"),
                ("title", "String", "Required", "title", "Stage title for this monitoring week.", "e.g. 'Week 3 - Early Whorl Stage'"),
                ("growthStage", "String (Enum)", "Required", "growthStage", "Phenological stage code.", "'SEEDLING', 'EARLY_WHORL', 'LATE_WHORL', 'TASSELING_SILKING', 'GRAIN_FILLING', 'MATURITY'"),
                ("startDate", "Timestamp", "Required", "startDate", "Start date of this weekly milestone.", "Timestamp"),
                ("endDate", "Timestamp", "Required", "endDate", "End date of this weekly milestone.", "Timestamp"),
                ("scoutingStatus", "String (Enum)", "Required", "scoutingStatus", "Scouting completion state.", "'pending', 'completed', 'skipped'"),
                ("fawStatus", "String (Enum)", "Optional", "fawStatus", "Fall armyworm presence indicator.", "'present', 'not_present', 'monitoring'"),
                ("tasks", "Array<Map>", "Optional", "tasks", "List of routine tasks scheduled for this week.", "[{'id': 't1', 'title': 'Apply Fertilizer', 'status': 'completed'}]")
            ]
        },
        {
            "id": "4.9",
            "name": "DAILY_ACTIVITY_LOGS",
            "phase": "Phase 04: Field Monitoring & Routine Logging",
            "desc": "Granular day-to-day farm activity records documenting irrigation, fertilization, chemical/organic spraying, weeding, and scouting.",
            "path": "users/{uid}/cycles/{cycleId}/dailyLogs/{dayId}/activities/{actId}",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique activity log identifier.", "e.g. 'act_log_78a1'"),
                ("cycleId", "String (FK)", "FK (CROPPING_CYCLES.id)", "cycleId", "Parent cycle ID.", "e.g. 'cycle_2026_q2_01'"),
                ("fieldId", "String (FK)", "FK (FARM_FIELDS.id)", "fieldId", "Associated field ID.", "e.g. 'field_plot_north_01'"),
                ("fieldName", "String", "Optional", "fieldName", "Field name.", "e.g. 'North Field'"),
                ("type", "String (Enum)", "Required", "type", "Category of farm operation executed.", "'irrigation', 'fertilization', 'pesticide', 'weeding', 'scouting', 'harvest'"),
                ("title", "String", "Required", "title", "Title/summary of the activity.", "e.g. 'Basal Fertilizer Application'"),
                ("description / notes", "String", "Optional", "description / notes", "Operational details, chemical dosage, or observations.", "e.g. 'Applied Complete 14-14-14 at 2 bags/ha'"),
                ("date", "Timestamp", "Required", "date", "Date of activity execution.", "Timestamp"),
                ("dayNumber / DAP", "Integer", "Optional", "dayNumber", "Days After Planting at execution time.", "e.g. 21"),
                ("weekNumber", "Integer", "Optional", "weekNumber", "Week number index.", "e.g. 3"),
                ("status", "String (Enum)", "Required", "status", "Execution status.", "'completed', 'scheduled', 'pending'"),
                ("isScheduled", "Boolean", "Optional", "isScheduled", "Whether activity was scheduled in advance.", "true, false"),
                ("scheduledFor", "Timestamp", "Optional", "scheduledFor", "Future execution target date/time.", "Timestamp"),
                ("images", "Array<String>", "Optional", "images", "List of photo URLs / file paths.", "['url1', 'url2']"),
                ("timestamp", "Timestamp", "Required", "timestamp", "Log creation server timestamp.", "ServerTimestamp")
            ]
        },
        {
            "id": "4.10",
            "name": "TRAP_MONITORING",
            "phase": "Phase 04: Field Monitoring & Routine Logging",
            "desc": "Stores pheromone and light trap inspection records, weekly adult moth catches, lure condition, and maintenance logs.",
            "path": "inspect_traps & users/{uid}/cycles/{cycleId}/traps/{trapId}",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique trap inspection record identifier.", "e.g. 'trap_insp_008'"),
                ("cycleId", "String (FK)", "FK (CROPPING_CYCLES.id)", "cycleId", "Associated growing cycle ID.", "e.g. 'cycle_2026_q2_01'"),
                ("fieldId", "String (FK)", "FK (FARM_FIELDS.id)", "fieldId", "Field where trap is stationed.", "e.g. 'field_plot_north_01'"),
                ("farmerId", "String (FK)", "FK (USERS.uid)", "farmerId", "Inspecting farmer UID.", "e.g. 'usr_89f4b7a12'"),
                ("trapName", "String", "Required", "trapName", "Designation of the trap.", "e.g. 'Pheromone Trap Alpha'"),
                ("trapType", "String (Enum)", "Required", "trapType", "Type of trap deployed.", "'Pheromone Trap', 'Light Trap', 'Sticky Trap'"),
                ("mothCount", "Integer", "Required", "mothCount / count", "Number of adult FAW moths counted.", "e.g. 14"),
                ("condition", "String (Enum)", "Required", "condition", "Physical trap & lure status.", "'Good', 'Damaged', 'Lure Needs Replacement'"),
                ("monitoringDate", "Timestamp", "Required", "date / monitoringDate", "Date inspection was performed.", "Timestamp"),
                ("notes", "String", "Optional", "notes", "Farmer observations regarding trap surroundings.", "e.g. 'Replaced sticky liner'"),
                ("images", "Array<String>", "Optional", "images", "Photos of trap basin and catch.", "['image_trap_1.jpg']")
            ]
        },
        {
            "id": "4.11",
            "name": "PEST_REPORTS",
            "phase": "Phase 05: AI Pest Detection & Image Inference",
            "desc": "Primary entity storing all field scouting and AI camera detection submissions, photos, coordinates, pest counts, and lifecycle statuses.",
            "path": "reports/{reportId}",
            "fields": [
                ("id / reportId", "String (UUID)", "PK", "id / reportId", "Unique Pest Report Identifier.", "e.g. 'rep_94a2b1f8'"),
                ("farmerId / reporterId", "String (FK)", "FK (USERS.uid)", "farmerId / reporterId", "UID of the reporting farmer.", "e.g. 'usr_89f4b7a12'"),
                ("farmerName", "String", "Optional", "farmerName / farmer", "Cached farmer name for fast dashboard indexing.", "e.g. 'Juan Dela Cruz'"),
                ("farmId", "String (FK)", "FK (FARMS.id)", "farmId", "Associated Farm Parcel ID.", "e.g. 'farm_east_parcel_01'"),
                ("fieldId", "String (FK)", "FK (FARM_FIELDS.id)", "fieldId", "Associated Field Plot ID.", "e.g. 'field_plot_north_01'"),
                ("fieldName", "String", "Optional", "fieldName", "Field name.", "e.g. 'North Field'"),
                ("cycleId", "String (FK)", "FK (CROPPING_CYCLES.id)", "cycleId", "Associated Cropping Cycle ID.", "e.g. 'cycle_2026_q2_01'"),
                ("reportType", "String (Enum)", "Required", "reportType", "Type of pest surveillance report.", "'regular' / 'ai_scan', 'clustered' / 'field_scouting'"),
                ("detection / pestName", "String", "Required", "detection / pest / name", "Primary pest identified (AI or Scout).", "e.g. 'Fall Armyworm (Spodoptera frugiperda)'"),
                ("scientificName", "String", "Optional", "scientificName", "Binomial taxonomic scientific name.", "e.g. 'Spodoptera frugiperda'"),
                ("lifeStage / stage", "String (Enum)", "Required", "lifeStage / stage", "Identified developmental life stage.", "'Egg Mass', 'Early Instar Larva', 'Late Instar Larva', 'Pupa', 'Adult Moth'"),
                ("cropAffected", "String", "Required", "cropAffected / crop", "Crop damaged by infestation.", "e.g. 'Maize (Corn)'"),
                ("severity / infestationLevel", "String (Enum)", "Required", "severity / infestation_level", "Assessed infestation intensity.", "'low', 'moderate', 'high', 'critical'"),
                ("riskLevel / risk", "String (Enum)", "Required", "riskLevel / risk", "Calculated threat level.", "'Low', 'Medium', 'High', 'Critical'"),
                ("confidence", "Double (0.0-1.0)", "Optional", "confidence", "YOLO AI detection confidence probability.", "e.g. 0.94"),
                ("boxes / boundingBoxes", "Array<Map>", "Optional", "boxes", "YOLO Bounding box coordinates [{x, y, width, height, class, confidence}].", "[{'x': 0.22, 'y': 0.35, 'width': 0.15, 'height': 0.20, 'confidence': 0.94}]"),
                ("analysis", "String", "Optional", "analysis", "AI-generated biological & damage diagnostic text.", "e.g. 'Late whorl stage feeding damage observed...'"),
                ("treatment", "String / Map", "Optional", "treatment", "Recommended IPM & chemical control guidelines.", "e.g. 'Apply Bacillus thuringiensis or Emamectin benzoate...'"),
                ("historicalContext", "String", "Optional", "historicalContext", "Historical trend and seasonal outbreak comparison notes.", "e.g. 'High seasonal pressure in this district during Q2'"),
                ("imageUrl / imageBase64", "String", "Required", "imageUrl / imageBase64", "Storage URL or Firestore Doc Ref ('firestore_image:users/...').", "URL or base64 string"),
                ("annotatedImageUrl", "String", "Optional", "annotatedImageUrl / annotated_url", "URL of photo with overlaid YOLO bounding boxes.", "URL to annotated JPG"),
                ("location", "Map<lat, lng> / GeoPoint", "Required", "location", "Exact GPS coordinates where photo was captured.", "{'lat': 10.7214, 'lng': 122.5638}"),
                ("locationMethod", "String (Enum)", "Optional", "locationMethod", "Method of coordinate acquisition.", "'gps', 'manual', 'qrcode'"),
                ("gpsAccuracy", "Double", "Optional", "gpsAccuracy", "GPS fix precision in meters.", "e.g. 4.2"),
                ("status", "String (Enum)", "Required", "status", "Report surveillance and validation status.", "'pending', 'validated', 'rejected', 'dismissed', 'resolved'"),
                ("resolutionExplanation", "String", "Optional", "resolutionExplanation", "Farmer's statement when marking pest resolved.", "e.g. 'Sprayed bio-pesticide, larval count reduced to 0'"),
                ("resolvedAt", "Timestamp", "Optional", "resolvedAt", "Timestamp when threat was resolved.", "Timestamp"),
                ("resolvedBy", "String (FK)", "Optional", "resolvedBy", "UID of farmer who resolved the threat.", "e.g. 'usr_89f4b7a12'"),
                ("timestamp / createdAt", "Timestamp", "Required", "timestamp / createdAt", "Report submission timestamp.", "ServerTimestamp")
            ]
        },
        {
            "id": "4.12",
            "name": "AI_PROCESSING",
            "phase": "Phase 05: AI Pest Detection & Image Inference",
            "desc": "Stores AI inference operational metadata, processing latency, model server endpoints, and execution outcomes.",
            "path": "reports/{reportId} (Inference Metadata)",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique inference job identifier.", "e.g. 'ai_job_99182'"),
                ("reportId", "String (FK)", "FK (PEST_REPORTS.id)", "reportId", "Associated pest report ID.", "e.g. 'rep_94a2b1f8'"),
                ("modelVersion", "String", "Required", "modelVersion", "YOLO model build and weight version.", "e.g. 'YOLOv8-FAW-v2.1'"),
                ("processingTimeMs", "Integer", "Required", "processingTimeMs", "End-to-end inference latency in milliseconds.", "e.g. 480"),
                ("status", "String (Enum)", "Required", "status", "Inference execution status.", "'success', 'failed', 'timeout', 'no_detection'"),
                ("endpoint", "String", "Optional", "endpoint", "FastAPI inference URL.", "e.g. '/predict'"),
                ("processedAt", "Timestamp", "Required", "processedAt", "Execution completion timestamp.", "Timestamp")
            ]
        },
        {
            "id": "4.13",
            "name": "AI_DETECTIONS",
            "phase": "Phase 05: AI Pest Detection & Image Inference",
            "desc": "Stores individual pest object detections from YOLO inference, bounding coordinates, confidence metrics, and stage classifications.",
            "path": "reports/{reportId} (boxes & detections array)",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique detection object identifier.", "e.g. 'det_box_01'"),
                ("reportId", "String (FK)", "FK (PEST_REPORTS.id)", "reportId", "Parent pest report ID.", "e.g. 'rep_94a2b1f8'"),
                ("pestType / className", "String", "Required", "className / class", "Detected pest category.", "e.g. 'Fall Armyworm'"),
                ("confidence", "Double (0.0-1.0)", "Required", "confidence", "Bounding box classification confidence.", "e.g. 0.94"),
                ("x", "Double (Normalized 0-1)", "Required", "x", "Bounding box center X coordinate.", "e.g. 0.45"),
                ("y", "Double (Normalized 0-1)", "Required", "y", "Bounding box center Y coordinate.", "e.g. 0.52"),
                ("width", "Double (Normalized 0-1)", "Required", "width", "Bounding box width.", "e.g. 0.18"),
                ("height", "Double (Normalized 0-1)", "Required", "height", "Bounding box height.", "e.g. 0.24"),
                ("lifeStage", "String (Enum)", "Optional", "lifeStage", "Predicted pest life stage for this detection.", "'Egg', 'Larva', 'Pupa', 'Adult Moth'")
            ]
        },
        {
            "id": "4.14",
            "name": "VALIDATION_QUEUE",
            "phase": "Phase 06: Expert Validation Queue",
            "desc": "Manages pending pest reports awaiting examination, triage, and diagnosis confirmation by RCPC crop protection experts.",
            "path": "validations/{validationId} (status: pending)",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Validation queue item identifier.", "e.g. 'val_queue_310'"),
                ("reportId", "String (FK)", "FK (PEST_REPORTS.id)", "reportId", "Pest report pending review.", "e.g. 'rep_94a2b1f8'"),
                ("submittedBy", "String (FK)", "FK (USERS.uid)", "submittedBy / farmerId", "Submitting farmer UID.", "e.g. 'usr_89f4b7a12'"),
                ("submittedDate", "Timestamp", "Required", "submittedDate / timestamp", "Report submission timestamp.", "Timestamp"),
                ("assignedExpert", "String (FK)", "Optional", "assignedExpert", "UID of assigned RCPC specialist.", "e.g. 'rcpc_expert_04'"),
                ("priority", "String (Enum)", "Required", "priority", "Queue triage priority based on risk level.", "'urgent', 'high', 'normal', 'low'"),
                ("status", "String (Enum)", "Required", "status", "Current queue processing status.", "'pending', 'under_review', 'validated', 'rejected'")
            ]
        },
        {
            "id": "4.15",
            "name": "EXPERT_VALIDATION",
            "phase": "Phase 06: Expert Validation Queue",
            "desc": "Stores official RCPC expert review findings, taxonomic confirmations, diagnostic corrections, risk assessments, and justifications.",
            "path": "validations/{validationId} & reports/{reportId}",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique Expert Validation Record ID.", "e.g. 'val_rec_502'"),
                ("reportId", "String (FK)", "FK (PEST_REPORTS.id)", "reportId", "Validated Pest Report ID.", "e.g. 'rep_94a2b1f8'"),
                ("reviewerId", "String (FK)", "FK (USERS.uid)", "validatedBy / reviewerId", "UID of validating RCPC crop expert.", "e.g. 'rcpc_specialist_07'"),
                ("reviewerName", "String", "Optional", "reviewerName", "Full name of the RCPC expert.", "e.g. 'Dr. Maria Santos, Entomologist'"),
                ("validationStatus", "String (Enum)", "Required", "status / validationStatus", "Expert validation verdict.", "'confirmed' / 'approved', 'corrected', 'rejected', 'false_positive'"),
                ("validatedPest", "String", "Optional", "validatedPest", "Confirmed/corrected pest species name.", "e.g. 'Fall Armyworm (Spodoptera frugiperda)'"),
                ("validatedLifeStage", "String (Enum)", "Optional", "validatedLifeStage", "Verified pest life stage.", "'Egg', 'Early Instar Larva', 'Late Instar Larva', 'Pupa', 'Adult'"),
                ("validatedSeverity", "String (Enum)", "Optional", "validatedSeverity", "Adjusted severity rating.", "'low', 'moderate', 'high', 'critical'"),
                ("expertNotes / comments", "String", "Optional", "internalNotes / comments", "Detailed scientific commentary and observations.", "e.g. 'Confirmed 3rd instar FAW larvae. Critical window for bio-spray.'"),
                ("rejectionReason", "String", "Optional", "rejectionReason", "Explanation if report was rejected or false positive.", "e.g. 'Image too blurry to confirm species'"),
                ("validatedAt", "Timestamp", "Required", "validationDate / validatedAt", "Timestamp of validation decision.", "ServerTimestamp")
            ]
        },
        {
            "id": "4.16",
            "name": "MITIGATION_ADVISORIES",
            "phase": "Phase 08: Mitigation Advisories & Alert Dispatch",
            "desc": "Stores tailored pest control advisories, urgent management recommendations, and chemical safety policies sent to farmers.",
            "path": "alerts/{alertId} & reports/{reportId}/advisory",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique advisory directive ID.", "e.g. 'adv_7710'"),
                ("detectionId / reportId", "String (FK)", "FK (PEST_REPORTS.id)", "reportId", "Associated validated pest detection.", "e.g. 'rep_94a2b1f8'"),
                ("farmerId", "String (FK)", "FK (USERS.uid)", "farmerId", "Recipient farmer UID.", "e.g. 'usr_89f4b7a12'"),
                ("advisoryText", "String", "Required", "treatment / advisoryText", "Complete step-by-step mitigation instructions.", "e.g. 'Apply Bt spray at early morning; handpick egg masses'"),
                ("controlMethods", "Array<String>", "Optional", "controlMethods", "List of IPM control method categories.", "['Cultural Control', 'Biological Spray', 'Chemical Intervention']"),
                ("urgencyLevel", "String (Enum)", "Required", "urgencyLevel / severity", "Action urgency level.", "'immediate', 'soon', 'preventive'"),
                ("sentAt", "Timestamp", "Required", "sentAt / publishedAt", "Advisory dispatch timestamp.", "ServerTimestamp")
            ]
        },
        {
            "id": "4.17",
            "name": "MANAGEMENT_ACTIONS",
            "phase": "Phase 09: Management Actions & Threat Resolution",
            "desc": "Logs farmer-executed pest mitigation interventions, chemicals/biocontrol agents applied, dosage rates, and application dates.",
            "path": "reports/{id}/actions & dailyLogs activities",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique management action identifier.", "e.g. 'act_mit_01'"),
                ("farmerId", "String (FK)", "FK (USERS.uid)", "farmerId", "Executing farmer UID.", "e.g. 'usr_89f4b7a12'"),
                ("reportId", "String (FK)", "FK (PEST_REPORTS.id)", "reportId", "Target pest report ID.", "e.g. 'rep_94a2b1f8'"),
                ("controlMethod", "String (Enum)", "Required", "controlMethod", "Mitigation method applied.", "'Biological (Bt/NPV)', 'Cultural (Handpicking/Intercropping)', 'Chemical (Insecticide)'"),
                ("chemicalName", "String", "Optional", "chemicalName", "Specific commercial product / active ingredient.", "e.g. 'Emamectin Benzoate 5% WDG'"),
                ("dosageRate", "String", "Optional", "dosageRate", "Applied dosage volume per hectare/knapsack.", "e.g. '15g per 16L tank'"),
                ("actionDate", "Timestamp", "Required", "actionDate", "Date intervention was executed.", "Timestamp"),
                ("status", "String (Enum)", "Required", "status", "Action completion status.", "'completed', 'in_progress', 'scheduled'"),
                ("notes", "String", "Optional", "notes", "Farmer's post-application observations.", "e.g. 'Targeted whorl area thoroughly'")
            ]
        },
        {
            "id": "4.18",
            "name": "REPORT_RESOLUTION",
            "phase": "Phase 09: Management Actions & Threat Resolution",
            "desc": "Captures formal pest threat resolution documentation, post-mitigation field observations, and clearance verification.",
            "path": "reports/{reportId} (resolution fields)",
            "fields": [
                ("id", "String (UUID)", "PK", "id / reportId", "Resolution transaction identifier.", "e.g. 'res_94a2'"),
                ("reportId", "String (FK)", "FK (PEST_REPORTS.id)", "reportId", "Resolved Pest Report ID.", "e.g. 'rep_94a2b1f8'"),
                ("resolvedBy", "String (FK)", "FK (USERS.uid)", "resolvedBy", "UID of resolving farmer.", "e.g. 'usr_89f4b7a12'"),
                ("resolvedByUserName", "String", "Optional", "resolvedByUserName", "Name of the farmer.", "e.g. 'Juan Dela Cruz'"),
                ("resolutionExplanation", "String", "Required", "resolutionExplanation", "Detailed statement describing how infestation was suppressed.", "e.g. 'Applied Bt spray twice; field scouting shows 0 active larvae'"),
                ("resolvedAt", "Timestamp", "Required", "resolvedAt", "Timestamp when report was marked resolved.", "ServerTimestamp"),
                ("status", "String", "Required", "status", "Status updated to resolved.", "'resolved'")
            ]
        },
        {
            "id": "4.19",
            "name": "RISK_ZONES",
            "phase": "Phase 07: GIS Risk Mapping & Proximity Alerts",
            "desc": "Geospatial boundary polygons and containment buffer zones representing pest outbreak clusters, risk tiers, and spread radius.",
            "path": "clustered_reports / GIS map layer",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique Risk Zone Identifier.", "e.g. 'zone_negros_d2_faw'"),
                ("name", "String", "Required", "name", "Descriptive zone title.", "e.g. 'District 2 FAW Outbreak Zone'"),
                ("riskLevel", "String (Enum)", "Required", "riskLevel / risk", "Aggregated risk rating of the zone.", "'Low', 'Medium', 'High', 'Critical'"),
                ("zoneGeometry", "Map / Polygon", "Required", "zoneGeometry / coordinates", "Geospatial GeoJSON polygon coordinates or center/radius.", "{'center': [10.72, 122.56], 'radiusMeters': 5000}"),
                ("affectedFarmCount", "Integer", "Optional", "affectedFarmCount", "Total number of farm parcels located inside this zone.", "e.g. 18"),
                ("activeReportCount", "Integer", "Optional", "activeReportCount", "Number of validated pest reports contributing to this zone.", "e.g. 7"),
                ("createdAt", "Timestamp", "Required", "createdAt", "Zone computation timestamp.", "ServerTimestamp")
            ]
        },
        {
            "id": "4.20",
            "name": "RISK_ZONE_SOURCE",
            "phase": "Phase 07: GIS Risk Mapping & Proximity Alerts",
            "desc": "Junction table mapping individual scout reports and trap counts that contribute to the formation and weight of each risk zone.",
            "path": "clustered_reports/{id}/sources",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique source linkage identifier.", "e.g. 'rzs_0019'"),
                ("riskZoneId", "String (FK)", "FK (RISK_ZONES.id)", "riskZoneId", "Parent risk zone ID.", "e.g. 'zone_negros_d2_faw'"),
                ("reportId", "String (FK)", "FK (PEST_REPORTS.id)", "reportId", "Contributing pest report ID.", "e.g. 'rep_94a2b1f8'"),
                ("contributionWeight", "Double", "Required", "contributionWeight", "Calculated statistical weight (based on confidence & severity).", "e.g. 0.85"),
                ("distanceFromCenterKm", "Double", "Optional", "distanceFromCenterKm", "Distance from zone hotspot centroid in km.", "e.g. 1.4")
            ]
        },
        {
            "id": "4.21",
            "name": "SPATIAL_CLUSTERS",
            "phase": "Phase 07: GIS Risk Mapping & Proximity Alerts",
            "desc": "Aggregated spatial cluster nodes generated from synchronized field scouting batches, moth trap counts, and plant damage rates.",
            "path": "clustered_reports/{clusterId}",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique cluster document ID.", "e.g. 'cl_rep_883'"),
                ("cycleId", "String (FK)", "FK (CROPPING_CYCLES.id)", "cycleId", "Associated cycle ID.", "e.g. 'cycle_2026_q2_01'"),
                ("reportType", "String", "Required", "reportType", "Cluster classification.", "'clustered'"),
                ("dap", "Integer", "Required", "dap", "Days After Planting for the cluster batch.", "e.g. 28"),
                ("growthStage", "String (Enum)", "Required", "growthStage", "Phenological stage of the cluster.", "'EARLY_WHORL'"),
                ("totalDamaged", "Integer", "Required", "totalDamaged", "Total plants damaged across scouted plants.", "e.g. 12"),
                ("totalInspected", "Integer", "Required", "totalInspected", "Total plants inspected in batch.", "e.g. 50"),
                ("damagePercentage", "Double", "Required", "damagePercentage", "Percentage of damaged crop plants.", "e.g. 24.0"),
                ("totals", "Map<String, Int>", "Required", "totals", "Aggregate pest stage counts: eggs, larvae, pupae, moths.", "{'eggs': 2, 'larvae': 14, 'pupae': 0, 'moths': 3}"),
                ("timestamp", "Timestamp", "Required", "timestamp", "Cluster compilation timestamp.", "Timestamp")
            ]
        },
        {
            "id": "4.22",
            "name": "ALERTS",
            "phase": "Phase 08: Mitigation Advisories & Alert Dispatch",
            "desc": "Broadcast alerts and urgent outbreak advisories published by RCPC/MAO to warn farmers of nearby pest pressure.",
            "path": "alerts/{alertId} & alertDrafts/{id}",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique Early Warning Alert Identifier.", "e.g. 'alt_9012a'"),
                ("createdBy", "String (FK)", "FK (USERS.uid)", "createdBy / senderId", "UID of the creating administrator/expert.", "e.g. 'rcpc_specialist_07'"),
                ("senderName", "String", "Optional", "senderName", "Display name / office of sender.", "e.g. 'Regional Crop Protection Center (Region VI)'"),
                ("senderRole", "String (Enum)", "Required", "senderRole", "Role of sender.", "'rcpc_admin', 'mao_admin'"),
                ("title", "String", "Required", "title", "Alert headline / subject.", "e.g. 'URGENT: Fall Armyworm Outbreak Alert - District 2'"),
                ("description", "String", "Required", "description / message", "Comprehensive advisory details and containment guidelines.", "e.g. 'Heavy FAW oviposition detected in neighboring barangays...'"),
                ("pestSpecies", "String", "Required", "pestSpecies / pestName", "Target pest species.", "e.g. 'Fall Armyworm (Spodoptera frugiperda)'"),
                ("affectedCrops", "Array<String>", "Required", "affectedCrops", "List of vulnerable crops.", "['Corn', 'Sorghum', 'Rice']"),
                ("severity", "String (Enum)", "Required", "severity", "Advisory severity level.", "'info', 'warning', 'critical'"),
                ("targetAudience", "String (Enum)", "Required", "targetAudience", "Audience distribution scope.", "'all', 'specific_farmers', 'specific_regions'"),
                ("affectedRegions", "Array<String>", "Optional", "affectedRegions", "Targeted municipalities/barangays.", "['Barangay San Jose', 'Barangay Granada']"),
                ("affectedFarms", "Array<String>", "Optional", "affectedFarms", "Specific farm IDs within contagion radius.", "['farm_01', 'farm_04']"),
                ("recommendations", "Array<Map>", "Optional", "recommendations", "List of IPM intervention steps [{action, priority, timing}].", "[{'action': 'Scout early morning', 'priority': 'immediate'}]"),
                ("status", "String (Enum)", "Required", "status", "Publishing lifecycle status.", "'draft', 'published', 'active', 'archived', 'expired'"),
                ("publishedAt", "Timestamp", "Required", "publishedAt", "Publication timestamp.", "ServerTimestamp"),
                ("validUntil", "Timestamp", "Optional", "validUntil / expiresAt", "Expiration timestamp of alert relevance.", "Timestamp"),
                ("viewCount", "Integer", "Optional", "viewCount", "Number of unique views logged.", "e.g. 142")
            ]
        },
        {
            "id": "4.23",
            "name": "ALERT_RECIPIENTS",
            "phase": "Phase 08: Mitigation Advisories & Alert Dispatch",
            "desc": "Tracks individual farmer notification deliveries, in-app notification badges, push notification status, and read receipts.",
            "path": "users/{uid}/notifications/{notifId}",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique notification message identifier.", "e.g. 'notif_usr_881'"),
                ("alertId", "String (FK)", "FK (ALERTS.id)", "alertId / data.alertId", "Associated broadcast alert ID.", "e.g. 'alt_9012a'"),
                ("userId / farmerId", "String (FK)", "FK (USERS.uid)", "userId / parent path", "Target farmer / recipient UID.", "e.g. 'usr_89f4b7a12'"),
                ("type", "String (Enum)", "Required", "type", "Notification category.", "'report_pending', 'report_proximity', 'farmer_registered', 'advisory', 'warning', 'info'"),
                ("title", "String", "Required", "title", "Notification header.", "e.g. 'Outbreak Alert: Fall Armyworm in 2.5km'"),
                ("message", "String", "Required", "message", "Notification body text.", "e.g. 'High FAW pressure detected in your area. Check trap counts.'"),
                ("read", "Boolean", "Required", "read", "Read / unread status.", "true, false (default: false)"),
                ("createdAt", "Timestamp", "Required", "createdAt", "Notification generation timestamp.", "ServerTimestamp"),
                ("data", "Map", "Optional", "data", "Metadata payload (reportId, detection, distance, coordinates).", "{'reportId': 'rep_94a2', 'distanceKm': 2.4}")
            ]
        },
        {
            "id": "4.24",
            "name": "REGIONAL_ADVISORIES",
            "phase": "Phase 08: Mitigation Advisories & Alert Dispatch",
            "desc": "High-level macro agricultural bulletins and seasonal pest warnings issued for entire provinces or agro-ecological zones.",
            "path": "alerts/{id} (scope: regional)",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Regional bulletin identifier.", "e.g. 'reg_adv_2026_04'"),
                ("title", "String", "Required", "title", "Bulletin title.", "e.g. 'Regional Corn Pest Advisory - Q2 2026'"),
                ("content", "String", "Required", "description", "Full textual body of the agro-climatic advisory.", "e.g. 'Favorable weather conditions for FAW multiplication expected...'"),
                ("severityLevel", "String (Enum)", "Required", "severity", "Severity classification.", "'info', 'warning', 'critical'"),
                ("validFrom", "Timestamp", "Required", "validFrom / publishedAt", "Advisory validity start date.", "Timestamp"),
                ("validTo", "Timestamp", "Required", "validUntil", "Advisory validity end date.", "Timestamp"),
                ("issuedBy", "String (FK)", "FK (USERS.uid)", "createdBy", "UID of issuing RCPC administrator.", "e.g. 'rcpc_specialist_07'")
            ]
        },
        {
            "id": "4.25",
            "name": "REGIONAL_ADVISORY_ZONES",
            "phase": "Phase 08: Mitigation Advisories & Alert Dispatch",
            "desc": "Junction linking regional bulletins to specific geographical administrative districts, municipalities, and risk zones.",
            "path": "alerts/{id} (affectedRegions array)",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Unique zone linkage identifier.", "e.g. 'raz_009'"),
                ("advisoryId", "String (FK)", "FK (REGIONAL_ADVISORIES.id)", "advisoryId", "Parent regional advisory ID.", "e.g. 'reg_adv_2026_04'"),
                ("riskZoneId", "String (FK)", "FK (RISK_ZONES.id)", "riskZoneId / regionName", "Target risk zone or administrative district.", "e.g. 'District 2', 'Bacolod City'")
            ]
        },
        {
            "id": "4.26",
            "name": "PEST_REFERENCES",
            "phase": "Pest Knowledge Base & Reference Library",
            "desc": "Master taxonomic reference catalog for all agricultural pests monitored by the system (scientific names, biology, host crops).",
            "path": "pestLibrary/{pestSlug}",
            "fields": [
                ("id / pestSlug", "String (Slug)", "PK", "id / slug", "Unique URL slug identifier.", "e.g. 'fall-armyworm'"),
                ("commonName", "String", "Required", "commonName / name", "Primary common name of the pest.", "e.g. 'Fall Armyworm'"),
                ("scientificName", "String", "Required", "scientificName", "Binomial taxonomic scientific name.", "e.g. 'Spodoptera frugiperda'"),
                ("description", "String", "Required", "description", "Comprehensive physical and biological description.", "e.g. 'A destructive lepidopteran pest native to tropical Americas...'"),
                ("hostCrops", "Array<String>", "Required", "hostCrops", "List of susceptible host crops.", "['Corn (Maize)', 'Rice', 'Sorghum', 'Sugarcane']"),
                ("damageType", "Array<String>", "Required", "damageType", "Patterns of damage inflicted.", "['Chewing', 'Defoliation', 'Ear Boring', 'Whorl Feeding']"),
                ("economicThreshold", "String", "Optional", "economicThreshold", "Infestation threshold requiring active intervention.", "e.g. '20% of plants showing fresh whorl feeding damage'"),
                ("integratedManagement", "String", "Required", "integratedManagement", "General IPM strategy overview.", "e.g. 'Combine pheromone monitoring, bio-pesticides, and crop rotation'"),
                ("images", "Array<String>", "Optional", "images", "High-resolution reference image URLs.", "['faw_larva_ref.jpg', 'faw_adult_ref.jpg']"),
                ("updatedAt", "Timestamp", "Required", "updatedAt", "Catalog last updated timestamp.", "Timestamp")
            ]
        },
        {
            "id": "4.27",
            "name": "PEST_LIFESTAGE_INFO",
            "phase": "Pest Knowledge Base & Reference Library",
            "desc": "Detailed biological life stage reference data (instar durations, morphological markers, and crop damage potential).",
            "path": "pestLibrary/{slug} (lifecycle object)",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Life stage entry identifier.", "e.g. 'ls_faw_larva'"),
                ("pestId / slug", "String (FK)", "FK (PEST_REFERENCES.id)", "pestId / parent slug", "Parent pest slug.", "e.g. 'fall-armyworm'"),
                ("lifeStage", "String (Enum)", "Required", "stages", "Developmental stage name.", "'Egg Mass', 'Early Instar Larva (1st-3rd)', 'Late Instar Larva (4th-6th)', 'Pupa', 'Adult Moth'"),
                ("durationDays", "String", "Optional", "duration", "Typical duration of this life stage in tropical climate.", "e.g. '14 - 22 days'"),
                ("damagePotential", "String (Enum)", "Required", "damagePotential", "Crop damage severity potential.", "'Critical', 'High', 'Moderate', 'None (Non-Feeding)'"),
                ("distinguishingFeatures", "Array<String>", "Optional", "identification.features", "Key visual identification markers.", "['Inverted Y on head capsule', 'Four dark spots arranged in square on 8th abdominal segment']")
            ]
        },
        {
            "id": "4.28",
            "name": "IPM_RECOMMENDATIONS",
            "phase": "Pest Knowledge Base & Reference Library",
            "desc": "Integrated Pest Management action protocols categorizing cultural, biological, and chemical control methods and pre-harvest intervals.",
            "path": "pestLibrary/{slug} (management object)",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "IPM guideline identifier.", "e.g. 'ipm_faw_01'"),
                ("pestId / slug", "String (FK)", "FK (PEST_REFERENCES.id)", "pestId / parent slug", "Associated pest reference slug.", "e.g. 'fall-armyworm'"),
                ("controlMethod", "String (Enum)", "Required", "controlMethod", "Control category.", "'Cultural Control', 'Biological Control', 'Chemical Control'"),
                ("recommendationText", "String", "Required", "recommendationText / culturalControl", "Detailed action recommendation.", "e.g. 'Plant early to avoid peak moth flights; intercrop with legumes'"),
                ("activeChemical", "String", "Optional", "chemicalControl.pesticide", "Authorized active ingredient.", "e.g. 'Chlorantraniliprole', 'Spinetoram', 'Bacillus thuringiensis'"),
                ("rateApplication", "String", "Optional", "chemicalControl.rateApplication", "Recommended application dosage.", "e.g. '200-300 ml/ha'"),
                ("preharvestIntervalDays", "Integer", "Optional", "chemicalControl.preharvest", "Days required between spray and harvest.", "e.g. 14")
            ]
        },
        {
            "id": "4.29",
            "name": "HISTORICAL_INVESTIGATIONS",
            "phase": "Phase 10: LGU-MAO Monitoring & Local Analytics",
            "desc": "Archive of historical pest outbreak events, environmental correlations, and evaluated mitigation efficacy for long-term predictive modeling.",
            "path": "reports (historical archive) & analytics",
            "fields": [
                ("id", "String (UUID)", "PK", "id", "Historical investigation case identifier.", "e.g. 'hist_case_2025_02'"),
                ("locationId / farmId", "String (FK)", "FK (FARMS.id)", "farmId", "Farm location of past event.", "e.g. 'farm_east_parcel_01'"),
                ("pestType", "String", "Required", "pestType", "Pest species involved.", "e.g. 'Fall Armyworm'"),
                ("eventDate", "Timestamp", "Required", "eventDate", "Date outbreak occurred.", "Timestamp"),
                ("peakInfestationRate", "Double", "Optional", "peakInfestationRate", "Maximum recorded crop damage percentage.", "e.g. 42.5"),
                ("successfulMitigation", "String", "Required", "successfulMitigation", "Control strategy that successfully suppressed the outbreak.", "e.g. 'Trichogramma egg parasitoid release combined with neem extract'")
            ]
        },
        {
            "id": "4.30",
            "name": "HARVEST_RECORDS",
            "phase": "Phase 11: Harvest Recording & Yield Documentation",
            "desc": "Captures final crop yield quantities, damaged versus marketable grain, loss rates, selling prices, and early harvest justifications.",
            "path": "users/{uid}/cycles/{cycleId} (harvest fields)",
            "fields": [
                ("id", "String (UUID)", "PK", "id / cycleId", "Harvest record identifier (corresponds to cycle ID).", "e.g. 'cycle_2026_q2_01'"),
                ("cycleId", "String (FK)", "FK (CROPPING_CYCLES.id)", "cycleId", "Parent cropping cycle ID.", "e.g. 'cycle_2026_q2_01'"),
                ("actualHarvestDate", "Timestamp", "Required", "actualHarvestDate", "Date harvest was carried out.", "ServerTimestamp"),
                ("expectedHarvestDate", "Timestamp", "Optional", "expectedHarvestDate", "Originally projected harvest date.", "Timestamp"),
                ("actualYield", "Double (kg/sacks/tons)", "Required", "actualYield", "Total harvested crop volume.", "e.g. 4500.0"),
                ("goodYield", "Double", "Required", "goodYield", "Marketable, undamaged crop yield volume.", "e.g. 4100.0"),
                ("damagedYield", "Double", "Required", "damagedYield", "Damaged crop volume caused by pest/disease.", "e.g. 400.0"),
                ("lossRate", "Double (Percentage)", "Required", "lossRate", "Calculated yield loss percentage (damaged / total).", "e.g. 8.88"),
                ("marketPrice", "Double (PHP)", "Required", "marketPrice", "Unit selling price per kg or sack (PHP).", "e.g. 18.00"),
                ("totalValue / grossIncome", "Double (PHP)", "Required", "totalValue / grossIncome", "Total gross value generated (goodYield * marketPrice).", "e.g. 73800.00"),
                ("isEarlyHarvest", "Boolean", "Required", "isEarlyHarvest", "Flag indicating whether crop was harvested prematurely.", "true, false"),
                ("daysEarly", "Integer", "Optional", "daysEarly", "Number of days harvested ahead of schedule.", "e.g. 7"),
                ("earlyHarvestReason", "String", "Optional", "earlyHarvestReason", "Reason for early harvesting (e.g. severe pest threat, weather).", "e.g. 'Severe late whorl infestation threatening ear formation'"),
                ("harvestNotes", "String", "Optional", "harvestNotes", "General harvest operational remarks.", "e.g. 'Harvested under dry weather conditions'"),
                ("status", "String", "Required", "status", "Status updated to harvested.", "'harvested'")
            ]
        },
        {
            "id": "4.31",
            "name": "FINANCIAL_OUTCOMES",
            "phase": "Phase 12: Cycle Completion & Financial Audit",
            "desc": "Calculates complete end-of-season financial outcomes, operational expenditure breakdowns, pest damage losses, and net farm profit.",
            "path": "users/{uid}/cycles/{cycleId} (financial audit fields)",
            "fields": [
                ("id", "String (UUID)", "PK", "id / cycleId", "Financial outcome record identifier.", "e.g. 'cycle_2026_q2_01'"),
                ("cycleId", "String (FK)", "FK (CROPPING_CYCLES.id)", "cycleId", "Parent cropping cycle ID.", "e.g. 'cycle_2026_q2_01'"),
                ("grossIncome", "Double (PHP)", "Required", "grossIncome / totalValue", "Total gross crop revenue (PHP).", "e.g. 73800.00"),
                ("seedsCost", "Double (PHP)", "Required", "seedsCost", "Expenditure on seeds and planting materials (PHP).", "e.g. 4500.00"),
                ("fertilizerCost", "Double (PHP)", "Required", "fertilizerCost", "Expenditure on inorganic/organic fertilizers (PHP).", "e.g. 8200.00"),
                ("controlMethodCost", "Double (PHP)", "Required", "controlMethodCost", "Expenditure on pest control, bio-sprays, and pesticides (PHP).", "e.g. 3500.00"),
                ("otherExpenses", "Double (PHP)", "Required", "otherExpenses", "Expenditure on labor, irrigation, fuel, and transport (PHP).", "e.g. 6000.00"),
                ("totalCycleCost", "Double (PHP)", "Required", "totalCycleCost", "Sum of all operational input and labor expenses (PHP).", "e.g. 22200.00"),
                ("damageCost / pestLoss", "Double (PHP)", "Required", "damageCost / pestLoss", "Monetary value of lost yield caused by pests (PHP).", "e.g. 7200.00"),
                ("netIncome", "Double (PHP)", "Required", "netIncome / income", "Final net profit / income (grossIncome - totalCycleCost) (PHP).", "e.g. 51600.00"),
                ("isAuditCompleted", "Boolean", "Required", "isAuditCompleted / isCompleted", "Audit completion flag.", "true"),
                ("auditCompletedAt", "Timestamp", "Required", "auditCompletedAt / completedAt", "Timestamp of final financial audit submission.", "ServerTimestamp")
            ]
        },
        {
            "id": "4.32",
            "name": "SYSTEM_CONFIG (APP_RELEASES)",
            "phase": "System Infrastructure & Remote Configuration",
            "desc": "Controls mobile application version gating, force-update minimum builds, maintenance mode flags, and download URLs.",
            "path": "app_releases/config",
            "fields": [
                ("id", "String", "PK", "id", "Static document key.", "'config'"),
                ("latestVersion", "String", "Required", "android.latestVersion", "Latest published mobile application version string.", "e.g. '2.0.0'"),
                ("latestBuild", "Integer", "Required", "android.latestBuild", "Latest published build number integer.", "e.g. 20"),
                ("minVersion", "String", "Required", "android.minVersion", "Minimum acceptable client version string.", "e.g. '1.5.0'"),
                ("minBuild", "Integer", "Required", "android.minBuild", "Minimum build number required to bypass update gate.", "e.g. 15"),
                ("downloadUrl", "String (URL)", "Required", "downloadUrl", "URL where latest APK / release can be downloaded.", "e.g. 'https://visaialanding.vercel.app/download'"),
                ("updateMessage", "String", "Required", "updateMessage", "Prompt message displayed to users requiring an update.", "e.g. 'A newer version of VISAIA is available. Please update.'"),
                ("maintenanceMode", "Boolean", "Required", "maintenanceMode", "System-wide maintenance lockdown switch.", "true, false (default: false)")
            ]
        }
    ]

    # Generate each detailed entity table
    tbl_cols = [Inches(1.4), Inches(1.0), Inches(1.1), Inches(1.3), Inches(1.5), Inches(1.2)]
    
    for ent in detailed_entities:
        add_heading_2(doc, f"{ent['id']} Entity: {ent['name']}")
        
        # Meta info
        p_meta = doc.add_paragraph()
        p_meta.paragraph_format.space_before = Pt(2)
        p_meta.paragraph_format.space_after = Pt(4)
        
        r1 = p_meta.add_run(f"System Lifecycle: ")
        r1.font.name = "Segoe UI"
        r1.font.bold = True
        r1.font.size = Pt(9)
        r1.font.color.rgb = RGBColor(27, 67, 50)
        
        r2 = p_meta.add_run(f"{ent['phase']}  |  ")
        r2.font.name = "Segoe UI"
        r2.font.size = Pt(9)
        
        r3 = p_meta.add_run(f"Physical Path: ")
        r3.font.name = "Segoe UI"
        r3.font.bold = True
        r3.font.size = Pt(9)
        r3.font.color.rgb = RGBColor(27, 67, 50)
        
        r4 = p_meta.add_run(f"`{ent['path']}`\n")
        r4.font.name = "Consolas"
        r4.font.size = Pt(8.5)
        
        r5 = p_meta.add_run(f"Description: {ent['desc']}")
        r5.font.name = "Segoe UI"
        r5.font.italic = True
        r5.font.size = Pt(9)
        r5.font.color.rgb = RGBColor(70, 80, 90)

        # Table
        tbl = doc.add_table(rows=len(ent['fields']) + 1, cols=6)
        tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
        tbl.autofit = False
        set_table_borders(tbl, color="D1D5DB")

        h_labels = ["Logical Field", "Data Type", "Constraints", "Firestore Key", "Description / Business Logic", "Valid Values / Example"]
        for i, h in enumerate(h_labels):
            tbl.cell(0, i).text = h
        format_table_header(tbl.rows[0], tbl_cols, bg_color="1B4332")

        for r_idx, fld in enumerate(ent['fields'], start=1):
            row = tbl.rows[r_idx]
            for c_idx, val in enumerate(fld):
                row.cells[c_idx].text = val
            format_data_row(row, tbl_cols, is_even=(r_idx % 2 == 0), font_size=8)

        doc.add_paragraph().paragraph_format.space_after = Pt(6)

    # -------------------------------------------------------------
    # Section 5: Cross-Entity Relationship Matrix
    # -------------------------------------------------------------
    add_heading_1(doc, "5. Cross-Entity Relationship & Cardinality Matrix")

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run(
        "The following matrix outlines the foreign key dependencies, navigational document hierarchy, and relational cardinalities across the VISAIA architecture:"
    )
    r.font.name = "Segoe UI"
    r.font.size = Pt(9.5)

    rel_cols = [Inches(1.5), Inches(1.5), Inches(1.0), Inches(1.5), Inches(2.0)]
    rel_table = doc.add_table(rows=16, cols=5)
    rel_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    rel_table.autofit = False
    set_table_borders(rel_table, color="D1D5DB")

    rel_headers = ["Source Entity", "Target Entity", "Cardinality", "Key / Foreign Key", "Relational Description"]
    for i, h in enumerate(rel_headers):
        rel_table.cell(0, i).text = h
    format_table_header(rel_table.rows[0], rel_cols, bg_color="1B4332")

    relationships = [
        ("USERS", "FARMERS", "1 : 1", "uid = farmerId", "Each registered farmer user account maps directly to an extended agricultural profile."),
        ("USERS (Farmer)", "FARMS", "1 : N", "users/{uid}/farms/{farmId}", "A farmer user owns and operates one or more distinct geographic farm parcels."),
        ("FARMS", "FARM_FIELDS", "1 : N", "users/{uid}/fields/{fieldId}", "A farm parcel is divided into one or more operational field plots."),
        ("FARM_FIELDS", "CROPPING_CYCLES", "1 : N", "fieldId in cycles", "A field plot hosts seasonal cropping cycles over time (growing and completed)."),
        ("CROPPING_CYCLES", "FIELD_MONITORING_TASKS", "1 : N", "cycles/{id}/weeks/{weekId}", "A growing cycle tracks weekly phenological milestones and tasks."),
        ("CROPPING_CYCLES", "DAILY_ACTIVITY_LOGS", "1 : N", "cycles/{id}/dailyLogs/activities", "Daily farm operations (spraying, weeding, fertilizer) logged per cycle."),
        ("CROPPING_CYCLES", "PEST_REPORTS", "1 : N", "cycleId in reports", "Scouting and AI pest reports are associated with the active crop cycle."),
        ("PEST_REPORTS", "AI_PROCESSING", "1 : 1", "reportId in AI metadata", "Each uploaded scouting photo triggers an AI inference execution job."),
        ("PEST_REPORTS", "VALIDATION_QUEUE", "1 : 1", "reportId in validations", "Pest reports enter the expert validation triage queue for RCPC review."),
        ("VALIDATION_QUEUE", "EXPERT_VALIDATION", "1 : 1", "validationId", "RCPC crop specialist validates, confirms, or corrects pest diagnosis."),
        ("EXPERT_VALIDATION", "MITIGATION_ADVISORIES", "1 : N", "reportId / advisoryId", "Validated reports generate specific IPM advisories and treatment directives."),
        ("PEST_REPORTS", "REPORT_RESOLUTION", "1 : 1", "reportId / resolution", "Farmer logs threat resolution when pest pressure is successfully controlled."),
        ("PEST_REPORTS", "SPATIAL_CLUSTERS", "N : 1", "reports contributing to cluster", "Pest reports within geographic proximity aggregate into risk clusters."),
        ("RISK_ZONES", "ALERTS", "1 : N", "riskZoneId in alerts", "High-risk zones trigger regional early warning broadcasts to nearby farms."),
        ("ALERTS", "ALERT_RECIPIENTS", "1 : N", "alertId in notifications", "Broadcast alerts dispatch notifications into targeted farmers' in-app inboxes.")
    ]

    for row_idx, data in enumerate(relationships, start=1):
        row = rel_table.rows[row_idx]
        for col_idx, text in enumerate(data):
            row.cells[col_idx].text = text
        format_data_row(row, rel_cols, is_even=(row_idx % 2 == 0), font_size=8.5)

    doc.add_paragraph().paragraph_format.space_after = Pt(10)

    # -------------------------------------------------------------
    # Section 6: Standard System Enumerations & Value Catalog
    # -------------------------------------------------------------
    add_heading_1(doc, "6. Standard System Enumerations & Value Catalog")

    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run(
        "To maintain data integrity across the Flutter client, Next.js web dashboard, and AI services, the following standard enumeration values are enforced:"
    )
    r.font.name = "Segoe UI"
    r.font.size = Pt(9.5)

    enum_cols = [Inches(1.8), Inches(2.2), Inches(3.5)]
    enum_table = doc.add_table(rows=9, cols=3)
    enum_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    enum_table.autofit = False
    set_table_borders(enum_table, color="D1D5DB")

    enum_headers = ["Enumeration Domain", "Allowed Constant Values", "Business Logic & Description"]
    for i, h in enumerate(enum_headers):
        enum_table.cell(0, i).text = h
    format_table_header(enum_table.rows[0], enum_cols, bg_color="1B4332")

    enums_data = [
        ("User Roles (`role`)", "'farmer', 'mao_admin', 'rcpc_admin', 'admin'", "Smallholder farmer (mobile app), MAO district officer (municipal dashboard), RCPC specialist (regional dashboard)."),
        ("Account Status (`status`)", "'pending', 'verified', 'approved', 'rejected'", "Farmer account approval lifecycle evaluated by MAO administrator."),
        ("Pest Report Status (`status`)", "'pending', 'validated', 'rejected', 'dismissed', 'resolved'", "Full pest surveillance lifecycle: AI detection -> expert review -> mitigation -> resolution."),
        ("Crop Growth Stages (`growthStage`)", "'SEEDLING', 'EARLY_WHORL', 'LATE_WHORL', 'TASSELING_SILKING', 'GRAIN_FILLING', 'MATURITY'", "Phenological corn development stages mapped from planting to harvest."),
        ("Pest Life Stages (`lifeStage`)", "'Egg Mass', 'Early Instar Larva', 'Late Instar Larva', 'Pupa', 'Adult Moth'", "Fall armyworm developmental instars identified by AI detection and verified by experts."),
        ("Severity Ratings (`severity`)", "'low', 'moderate', 'high', 'critical'", "Infestation intensity rating calculated from damage percentage and pest counts."),
        ("Risk Levels (`riskLevel`)", "'Low', 'Medium', 'High', 'Critical'", "Geospatial outbreak threat level computed for GIS risk zones and proximity maps."),
        ("Activity Types (`type`)", "'irrigation', 'fertilization', 'pesticide', 'weeding', 'scouting', 'harvest'", "Daily operational farm logging categories in the mobile application.")
    ]

    for row_idx, data in enumerate(enums_data, start=1):
        row = enum_table.rows[row_idx]
        for col_idx, text in enumerate(data):
            row.cells[col_idx].text = text
        format_data_row(row, enum_cols, is_even=(row_idx % 2 == 0), font_size=8.5)

    # -------------------------------------------------------------
    # Save the Document
    # -------------------------------------------------------------
    output_path = r'c:\PROJECTS\visaia\Updated_Data_Dictionary.docx'
    doc.save(output_path)
    print(f"Successfully generated comprehensive Data Dictionary docx at: {output_path}")

if __name__ == '__main__':
    create_full_data_dictionary()
