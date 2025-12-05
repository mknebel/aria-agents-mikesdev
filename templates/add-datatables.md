# DataTables Conversion Template

## Purpose
Convert a CakePHP server-side paginated table to a full-featured DataTables implementation with:
- Server-side processing (AJAX)
- Column visibility toggle
- Export (Excel, CSV, PDF, Print)
- Loading state management
- State saving

## Prerequisites
1. Existing controller with `index()` action
2. Existing template with HTML table
3. DataTablesComponent available

## Files to Create/Modify

### 1. Controller: Add `ajaxList()` and `ajaxExport()` methods

```php
/**
 * Server-side DataTables AJAX endpoint
 */
public function ajaxList()
{
    $this->request->allowMethod(['get', 'post']);
    $this->viewBuilder()->disableAutoLayout();
    $this->loadComponent('DataTables');

    // Build conditions from filters
    $conditions = [];
    // Add filter logic here based on request data

    // Column configuration
    $columns = [
        'id' => [
            'field' => 'id',
            'order_field' => 'TableName.id',
            'searchable' => false,
            'orderable' => true,
        ],
        // Add more columns...
        'actions' => [
            'field' => 'id',
            'searchable' => false,
            'orderable' => false,
            'formatter' => function ($entity, $value) {
                return '<a href="/view/' . $entity->id . '" class="btn btn-sm btn-outline-secondary"><i class="bi bi-eye"></i></a>';
            }
        ],
    ];

    $options = [
        'contain' => ['RelatedTable'],
        'conditions' => $conditions,
    ];

    $result = $this->DataTables->process($this->TableName, $columns, $options);

    return $this->response
        ->withType('application/json')
        ->withStringBody(json_encode($result));
}

/**
 * Export all filtered records
 */
public function ajaxExport()
{
    $this->request->allowMethod(['get', 'post']);
    $this->viewBuilder()->disableAutoLayout();

    // Build query with same filters as ajaxList
    $query = $this->TableName->find()
        ->contain(['RelatedTable'])
        ->where($conditions)
        ->limit(10000);

    $data = [];
    foreach ($query->all() as $entity) {
        $data[] = [
            'id' => $entity->id,
            // Map all columns for export
        ];
    }

    return $this->response
        ->withType('application/json')
        ->withStringBody(json_encode(['data' => $data]));
}
```

### 2. JavaScript: Create `tablename-datatable.js`

Key features to include:
- `exportAllRecords()` function for Excel/CSV/PDF/Print
- Loading state management with `isProcessing` flag
- `processing.dt` event handler
- Filter change handlers that trigger `table.ajax.reload()`
- State saving with `stateSave: true`
- Column visibility with colvis button

### 3. Template: Update with DataTables structure

```php
<?php
// Build AJAX URL
$ajaxUrl = $this->Url->build([
    'prefix' => $currentPrefix,
    'controller' => 'ControllerName',
    'action' => 'ajaxList'
]);
?>

<!-- DataTables CSS -->
<?= $this->Html->css([
    'https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css',
    'https://cdn.datatables.net/buttons/2.4.1/css/buttons.bootstrap5.min.css',
], ['block' => true]) ?>

<!-- Table with data-ajax-url -->
<table id="tablename-table" data-ajax-url="<?= h($ajaxUrl) ?>">
    <thead>
        <tr>
            <!-- Column headers matching JS columns array -->
        </tr>
    </thead>
    <tbody></tbody>
</table>

<!-- DataTables JS -->
<?= $this->Html->script([
    'https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js',
    'https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js',
    'https://cdn.datatables.net/buttons/2.4.1/js/dataTables.buttons.min.js',
    'https://cdn.datatables.net/buttons/2.4.1/js/buttons.bootstrap5.min.js',
    'https://cdn.datatables.net/buttons/2.4.1/js/buttons.colVis.min.js',
    'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js',
    'https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/pdfmake.min.js',
    'https://cdnjs.cloudflare.com/ajax/libs/pdfmake/0.2.7/vfs_fonts.js',
    'https://cdn.sheetjs.com/xlsx-0.20.0/package/dist/xlsx.full.min.js',
], ['block' => true]) ?>

<?= $this->Html->script('tablename-datatable', ['block' => true]) ?>
```

### 4. Required CSS for loading state

```css
.dataTables_wrapper.dt-loading {
    pointer-events: none;
    position: relative;
}
.dataTables_wrapper.dt-loading::after {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(255, 255, 255, 0.5);
    z-index: 10;
}
```

## Reference Implementation
- `webroot/js/recurring-profiles-datatable.js` - Full-featured example
- `templates/Admin/AuthnetRecurringProfiles/view_recurring.php` - Template example

## Column Count Rule
**CRITICAL**: JS `columns[]` array count MUST match HTML `<th>` count exactly!
