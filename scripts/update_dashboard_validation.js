const fs = require('fs');
const path = require('path');

const detailPath = 'c:/PROJECTS/visaia-dashboard/app/(dashboard)/validation/[id]/page.tsx';
const listPath = 'c:/PROJECTS/visaia-dashboard/app/(dashboard)/validation/page.tsx';

// 1. Update validation/[id]/page.tsx
if (fs.existsSync(detailPath)) {
  let detailContent = fs.readFileSync(detailPath, 'utf8');

  // Insert alert creation in handleConfirm
  if (!detailContent.includes("type: 'validation_confirmed'")) {
    const targetValidationUpdate = `showModal(
        'Validation Submitted',`;

    const alertValidationCode = `// Send alert notification to the farmer
      const targetFarmerId = report.farmerId || (report as any).userId;
      if (targetFarmerId) {
        try {
          await addDoc(collection(db, 'alerts'), {
            farmerId: targetFarmerId,
            reportId: report.id,
            reportType: isClustered ? 'clustered' : 'regular',
            farmId: report.farmId || '',
            farmName: report.farmName || '',
            fieldName: report.fieldName || '',
            title: isClustered
              ? \`Scouting Report Validated (\${report.growthStage || 'Corn'} Stage)\`
              : \`Pest Report Validated: \${diagnosis === 'other' ? otherPestName : (report.detection || 'Pest Detection')}\`,
            message: advisoryMessage || internalNotes || 'Your submitted report has been reviewed and validated by RCPC officers.',
            detection: isClustered ? 'FAW Clustered Scouting' : (diagnosis === 'other' ? otherPestName : (report.detection || 'Pest Detection')),
            risk: isClustered ? (report.riskLevel || 'Moderate') : (report.risk || 'Low'),
            cropAffected: report.cropAffected || (report as any).cropType || 'Corn',
            lifeStage: isClustered ? (report.growthStage || 'Vegetative') : (diagnosis === 'wrong_stage' ? correctedStage : (report.lifeStage || 'Unknown')),
            status: 'unread',
            type: 'validation_confirmed',
            validatedBy: 'RCPC Officer',
            validationNotes: internalNotes || '',
            advisoryMessage: advisoryMessage || '',
            validatedAt: serverTimestamp(),
            createdAt: serverTimestamp(),
          });
        } catch (alertErr) {
          console.error('Error creating validation alert for farmer:', alertErr);
        }
      }

      showModal(
        'Validation Submitted',`;

    detailContent = detailContent.replace(targetValidationUpdate, alertValidationCode);
  }

  // Insert alert creation in handleReject
  if (!detailContent.includes("type: 'validation_rejected'")) {
    const targetRejectUpdate = `showModal(
        'Report Rejected',`;

    const alertRejectCode = `// Send rejection alert to the farmer
      const targetFarmerId = report.farmerId || (report as any).userId;
      if (targetFarmerId) {
        try {
          await addDoc(collection(db, 'alerts'), {
            farmerId: targetFarmerId,
            reportId: report.id,
            reportType: isClustered ? 'clustered' : 'regular',
            farmId: report.farmId || '',
            farmName: report.farmName || '',
            fieldName: report.fieldName || '',
            title: isClustered
              ? \`Scouting Report Rejected\`
              : \`Pest Report Rejected: \${report.detection || 'Pest Detection'}\`,
            message: \`Report was rejected by RCPC. Reason: \${rejectReason}\`,
            detection: isClustered ? 'FAW Clustered Scouting' : (report.detection || 'Pest Report'),
            risk: isClustered ? (report.riskLevel || 'Moderate') : (report.risk || 'Low'),
            cropAffected: report.cropAffected || (report as any).cropType || 'Corn',
            lifeStage: isClustered ? (report.growthStage || 'Vegetative') : (report.lifeStage || 'Unknown'),
            status: 'unread',
            type: 'validation_rejected',
            rejectionReason: rejectReason,
            validatedBy: 'RCPC Officer',
            validatedAt: serverTimestamp(),
            createdAt: serverTimestamp(),
          });
        } catch (alertErr) {
          console.error('Error creating rejection alert for farmer:', alertErr);
        }
      }

      showModal(
        'Report Rejected',`;

    detailContent = detailContent.replace(targetRejectUpdate, alertRejectCode);
  }

  fs.writeFileSync(detailPath, detailContent, 'utf8');
  console.log('Successfully updated validation/[id]/page.tsx');
} else {
  console.log('detailPath not found:', detailPath);
}

// 2. Update validation/page.tsx for handleConfirmReject and ensure addDoc is imported
if (fs.existsSync(listPath)) {
  let listContent = fs.readFileSync(listPath, 'utf8');

  // Ensure addDoc is imported
  if (!listContent.includes('addDoc,')) {
    listContent = listContent.replace(
      "updateDoc,",
      "updateDoc,\n  addDoc,"
    );
  }

  if (!listContent.includes("type: 'validation_rejected'")) {
    const targetListReject = `setRejectModalOpen(false);
      setRejectTargetId(null);`;

    const alertListRejectCode = `// Send alert to farmer
      try {
        const targetItem = filteredData.find((item) => item.id === rejectTargetId);
        const farmerId = (targetItem as any)?.farmerId || (targetItem as any)?.userId;
        if (farmerId) {
          await addDoc(collection(db, 'alerts'), {
            farmerId: farmerId,
            reportId: rejectTargetId,
            reportType: rejectTargetType,
            farmId: (targetItem as any)?.farmId || '',
            farmName: (targetItem as any)?.farmName || '',
            title: rejectTargetType === 'clustered'
              ? 'Scouting Report Rejected'
              : \`Pest Report Rejected: \${(targetItem as any)?.detection || 'Pest Detection'}\`,
            message: \`Report was rejected by RCPC. Reason: \${reason}\`,
            detection: rejectTargetType === 'clustered' ? 'FAW Clustered Scouting' : ((targetItem as any)?.detection || 'Pest Report'),
            risk: (targetItem as any)?.riskLevel || (targetItem as any)?.risk || 'Moderate',
            status: 'unread',
            type: 'validation_rejected',
            rejectionReason: reason,
            validatedBy: 'RCPC Officer',
            validatedAt: serverTimestamp(),
            createdAt: serverTimestamp(),
          });
        }
      } catch (errAlert) {
        console.error('Error creating rejection alert:', errAlert);
      }

      setRejectModalOpen(false);
      setRejectTargetId(null);`;

    listContent = listContent.replace(targetListReject, alertListRejectCode);
  }

  fs.writeFileSync(listPath, listContent, 'utf8');
  console.log('Successfully updated validation/page.tsx');
} else {
  console.log('listPath not found:', listPath);
}
