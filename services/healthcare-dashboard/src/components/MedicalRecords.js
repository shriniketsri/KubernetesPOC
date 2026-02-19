import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  TextField,
  IconButton,
  Chip,
  CircularProgress,
  Accordion,
  AccordionSummary,
  AccordionDetails,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  Refresh as RefreshIcon,
  ExpandMore as ExpandMoreIcon,
} from '@mui/icons-material';
import { DateTimePicker } from '@mui/x-date-pickers/DateTimePicker';
import { toast } from 'react-toastify';
import { medicalRecordsService } from '../services/api';
import dayjs from 'dayjs';

const MedicalRecords = () => {
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(true);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingRecord, setEditingRecord] = useState(null);
  const [formData, setFormData] = useState({
    patient_id: '',
    doctor_id: '',
    diagnosis: '',
    treatment: '',
    medications: '',
    notes: '',
    follow_up_date: null,
    created_by: '',
  });

  useEffect(() => {
    fetchMedicalRecords();
  }, []);

  const fetchMedicalRecords = async () => {
    try {
      setLoading(true);
      const response = await medicalRecordsService.getAll();
      setRecords(response.data || []);
    } catch (error) {
      console.error('Error fetching medical records:', error);
      toast.error('Error loading medical records');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async () => {
    try {
      const recordData = {
        ...formData,
        follow_up_date: formData.follow_up_date ? formData.follow_up_date.toISOString() : null,
      };

      if (editingRecord) {
        await medicalRecordsService.update(editingRecord.id || editingRecord._id, recordData);
        toast.success('Medical record updated successfully');
      } else {
        await medicalRecordsService.create(recordData);
        toast.success('Medical record created successfully');
      }

      setDialogOpen(false);
      resetForm();
      fetchMedicalRecords();
    } catch (error) {
      console.error('Error saving medical record:', error);
      toast.error('Error saving medical record');
    }
  };

  const handleEdit = (record) => {
    setEditingRecord(record);
    setFormData({
      patient_id: record.patient_id || '',
      doctor_id: record.doctor_id || '',
      diagnosis: record.diagnosis || '',
      treatment: record.treatment || '',
      medications: record.medications || '',
      notes: record.notes || '',
      follow_up_date: record.follow_up_date ? dayjs(record.follow_up_date) : null,
      created_by: record.created_by || '',
    });
    setDialogOpen(true);
  };

  const handleDelete = async (record) => {
    if (window.confirm(`Are you sure you want to delete this medical record?`)) {
      try {
        await medicalRecordsService.delete(record.id || record._id);
        toast.success('Medical record deleted successfully');
        fetchMedicalRecords();
      } catch (error) {
        console.error('Error deleting medical record:', error);
        toast.error('Error deleting medical record');
      }
    }
  };

  const resetForm = () => {
    setFormData({
      patient_id: '',
      doctor_id: '',
      diagnosis: '',
      treatment: '',
      medications: '',
      notes: '',
      follow_up_date: null,
      created_by: '',
    });
    setEditingRecord(null);
  };

  const handleAddNew = () => {
    resetForm();
    setDialogOpen(true);
  };

  const formatDateTime = (dateString) => {
    if (!dateString) return 'N/A';
    return dayjs(dateString).format('MMM DD, YYYY HH:mm');
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'N/A';
    return dayjs(dateString).format('MMM DD, YYYY');
  };

  return (
    <Box>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">Medical Records</Typography>
        <Box>
          <Button
            startIcon={<RefreshIcon />}
            onClick={fetchMedicalRecords}
            sx={{ mr: 2 }}
          >
            Refresh
          </Button>
          <Button
            variant="contained"
            startIcon={<AddIcon />}
            onClick={handleAddNew}
          >
            Add Record
          </Button>
        </Box>
      </Box>

      {loading ? (
        <Box display="flex" justifyContent="center" py={4}>
          <CircularProgress />
        </Box>
      ) : (
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Patient ID</TableCell>
                <TableCell>Doctor ID</TableCell>
                <TableCell>Diagnosis</TableCell>
                <TableCell>Treatment</TableCell>
                <TableCell>Date Created</TableCell>
                <TableCell>Follow-up</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {records.map((record) => (
                <TableRow key={record.id || record._id}>
                  <TableCell>{record.patient_id}</TableCell>
                  <TableCell>{record.doctor_id}</TableCell>
                  <TableCell>
                    <Typography variant="body2" noWrap>
                      {record.diagnosis || 'No diagnosis'}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" noWrap>
                      {record.treatment || 'No treatment specified'}
                    </Typography>
                  </TableCell>
                  <TableCell>{formatDateTime(record.created_at || record.createdAt)}</TableCell>
                  <TableCell>
                    {record.follow_up_date ? (
                      <Chip
                        label={formatDate(record.follow_up_date)}
                        color="info"
                        size="small"
                      />
                    ) : (
                      <Typography variant="body2" color="text.secondary">
                        None scheduled
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell align="right">
                    <IconButton
                      size="small"
                      onClick={() => handleEdit(record)}
                      color="primary"
                    >
                      <EditIcon />
                    </IconButton>
                    <IconButton
                      size="small"
                      onClick={() => handleDelete(record)}
                      color="error"
                    >
                      <DeleteIcon />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
              {records.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} align="center">
                    <Typography color="text.secondary">
                      No medical records found. Add your first medical record!
                    </Typography>
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="lg" fullWidth>
        <DialogTitle>
          {editingRecord ? 'Edit Medical Record' : 'Add New Medical Record'}
        </DialogTitle>
        <DialogContent>
          <Box component="form" sx={{ pt: 2 }}>
            <TextField
              fullWidth
              label="Patient ID"
              value={formData.patient_id}
              onChange={(e) => setFormData({ ...formData, patient_id: e.target.value })}
              margin="normal"
              required
              helperText="Enter the patient identifier"
            />
            <TextField
              fullWidth
              label="Doctor ID"
              value={formData.doctor_id}
              onChange={(e) => setFormData({ ...formData, doctor_id: e.target.value })}
              margin="normal"
              required
              helperText="Enter the attending doctor identifier"
            />
            <TextField
              fullWidth
              label="Diagnosis"
              multiline
              rows={2}
              value={formData.diagnosis}
              onChange={(e) => setFormData({ ...formData, diagnosis: e.target.value })}
              margin="normal"
              required
              helperText="Primary diagnosis and condition"
            />
            <TextField
              fullWidth
              label="Treatment"
              multiline
              rows={3}
              value={formData.treatment}
              onChange={(e) => setFormData({ ...formData, treatment: e.target.value })}
              margin="normal"
              helperText="Treatment plan and procedures"
            />
            <TextField
              fullWidth
              label="Medications"
              multiline
              rows={2}
              value={formData.medications}
              onChange={(e) => setFormData({ ...formData, medications: e.target.value })}
              margin="normal"
              helperText="Prescribed medications and dosage"
            />
            <DateTimePicker
              label="Follow-up Date (Optional)"
              value={formData.follow_up_date}
              onChange={(newValue) => setFormData({ ...formData, follow_up_date: newValue })}
              renderInput={(params) => (
                <TextField
                  {...params}
                  fullWidth
                  margin="normal"
                />
              )}
            />
            <TextField
              fullWidth
              label="Created By"
              value={formData.created_by}
              onChange={(e) => setFormData({ ...formData, created_by: e.target.value })}
              margin="normal"
              required
              helperText="Doctor or healthcare provider name"
            />
            <TextField
              fullWidth
              label="Additional Notes"
              multiline
              rows={4}
              value={formData.notes}
              onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
              margin="normal"
              helperText="Additional observations, symptoms, or notes"
            />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleSubmit} variant="contained">
            {editingRecord ? 'Update' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default MedicalRecords;